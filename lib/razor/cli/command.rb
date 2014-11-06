class Razor::CLI::Command
  def initialize(parse, navigate, commands, segments)
    @parse = parse
    @navigate = navigate
    @commands = commands
    @segments = segments
  end

  def run
    # @todo lutter 2013-08-16: None of this has any tests, and error
    # handling is heinous at best
    cmd, body = extract_command
    # Ensure that we copy authentication data from our previous URL.
    url = URI.parse(cmd["id"])
    if @doc_resource
      url          = URI.parse(url.to_s)
    end

    if @parse.show_command_help?
      @navigate.json_get(url)
    else
      if body.empty?
        raise Razor::CLI::Error,
              "No arguments for command (did you forget --json ?)"
      end
      result = @navigate.json_post(url, body)
      # Get actual object from the id.
      result = result.merge(@navigate.json_get(URI.parse(result['id']))) if result['id']
      result
    end
  end

  def command(name)
    @command ||= @commands.find { |coll| coll["name"] == name }
  end

  def extract_command
    cmd = command(@segments.shift)
    @cmd_url = URI.parse(cmd['id'])
    body = {}
    until @segments.empty?
      argument = @segments.shift
      if argument =~ /\A--([a-z-]+)(=(.+))?\Z/
        # `--arg=value` or `--arg value`
        arg, value = [$1, $3]
        value = @segments.shift if value.nil? && @segments[0] !~ /^--/
        body[arg] = convert_arg(cmd["name"], arg, value, body[arg])
      else
        raise ArgumentError, "Unexpected argument #{argument}"
      end
    end

    begin
      body = MultiJson::load(File::read(body["json"])) if body["json"]
    rescue MultiJson::LoadError
      raise Razor::CLI::Error, "File #{body["json"]} is not valid JSON"
    rescue Errno::ENOENT
      raise Razor::CLI::Error, "File #{body["json"]} not found"
    rescue Errno::EACCES
      raise Razor::CLI::Error,
            "Permission to read file #{body["json"]} denied"
    end
    [cmd, body]
  end

  def cmd_schema(cmd_name)
    begin
      @navigate.json_get(@cmd_url)['schema']
    rescue RestClient::ResourceNotFound => _
      raise VersionCompatibilityError, 'Server must supply the expected datatypes for command arguments; use `--json` or upgrade razor-server'
    end
  end

  def arg_type(cmd_name, arg_name)
    # Short-circuit to allow this as a work-around for backwards compatibility.
    return nil if arg_name == 'json'
    cmd = cmd_schema(cmd_name)
    cmd && cmd[arg_name] && cmd[arg_name]['type'] or nil
  end

  # `cmd_name`: The name of the command being executed.
  # `arg_name`: The name of the argument being formatted.
  # `value`: The original value provided by the user.
  # `existing_value`: The value already assigned to this variable
  #     by previous calls to this method. The new `value` will be
  #     concatenated to an array or hash if an array/hash is
  #     accepted by the command for the given argument.
  def convert_arg(cmd_name, arg_name, value, existing_value)
    value = nil if value == "null"

    argument_type = arg_type(cmd_name, arg_name)

    # This might be helpful, since there's no other method for debug-level logging on the client.
    puts "Formatting argument #{arg_name} with value #{value} as #{argument_type}\n" if @parse.dump_response?

    case argument_type
      when "array"
        existing_value ||= []
        begin
          MultiJson::load(value).tap do |value|
            value = Array(value)
            existing_value + value
          end
        rescue MultiJson::LoadError => _
          existing_value + Array(value)
        end
      when "object"
        existing_value ||= {}
        begin
          if value =~ /\A(.+?)=(.+)?\z/
            # `--arg name=value`
            existing_value.merge($1 => $2)
          else
            MultiJson::load(value).tap do |value|
              value.is_a?(Hash) or raise ArgumentError, "Invalid object for argument '#{arg_name}'"
              existing_value.merge(value)
            end
          end
        rescue MultiJson::LoadError => error
          raise ArgumentError, "Invalid object for argument '#{arg_name}': #{error.message}"
        end
      when "boolean"
        ["true", nil].include?(value)
      when "number"
        begin
          Integer(value)
        rescue ArgumentError
          raise ArgumentError, "Invalid integer for argument '#{arg_name}': #{value}"
        end
      when "null"
        raise ArgumentError, "Expected nothing for argument '#{arg_name}', but was: '#{value}'" unless value.nil?
        nil
      when "string", nil # `nil` for 'might be an alias, send as-is'
        value
      else
        raise Razor::CLI::Error, "Unexpected datatype '#{argument_type}' for argument #{arg_name}"
    end
  end
end