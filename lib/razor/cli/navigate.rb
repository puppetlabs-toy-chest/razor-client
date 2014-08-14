require 'rest-client'
require 'multi_json'
require 'yaml'
require 'forwardable'

module Razor::CLI
  class Navigate
    extend Forwardable

    def initialize(parse, segments)
      @parse = parse
      @segments = segments||[]
      @doc = entrypoint
      @username, @password = parse.api_url.userinfo.to_s.split(':')
      @doc_resource = create_resource parse.api_url, {:accept => :json}
    end

    def last_url
      @doc_resource
    end

    def entrypoint
      @entrypoint ||= json_get(@parse.api_url)
    end

    def collections
      entrypoint["collections"]
    end

    def commands
      entrypoint["commands"]
    end

    def server_version
      entrypoint.has_key?('version') and entrypoint['version']['server'] or 'Unknown'
    end

    def query?
      @query ||= collections.any? { |coll| coll["name"] == @segments.first }
    end

    def command(name)
      @command ||= commands.find { |coll| coll["name"] == name }
    end

    def command?
      !! command(@segments.first)
    end

    def_delegator '@parse', 'show_command_help?'

    def get_document
      if @segments.empty?
        entrypoint
      elsif query?
        @doc = collections
        while @segments.any?
          move_to @segments.shift
        end

        # Get the next level if it's a list of objects.
        if @doc.is_a?(Hash) and @doc['items'].is_a?(Array)
          @doc['items'] = @doc['items'].map do |item|
            item.is_a?(Hash) && item.has_key?('id') ? json_get(item['id']) : item
          end
        end
        @doc
      elsif command?
        # @todo lutter 2013-08-16: None of this has any tests, and error
        # handling is heinous at best
        cmd, body = extract_command
        # Ensure that we copy authentication data from our previous URL.
        url = cmd["id"]
        if @doc_resource
          url          = URI.parse(url.to_s)
        end

        if show_command_help?
          json_get(url)
        else
          if body.empty?
            raise Razor::CLI::Error,
                  "No arguments for command (did you forget --json ?)"
          end
          result = json_post(url, body)
          # Get actual object from the id.
          result = result.merge(json_get(result['id'])) if result['id']
          result
        end
      else
        raise NavigationError.new(@doc_resource, @segments, @doc)
      end
    end

    def extract_command
      cmd = command(@segments.shift)
      @cmd_url = cmd['id']
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

    def move_to(key)
      if @doc.is_a? Array
        obj = @doc.find {|x| x.is_a?(Hash) and x["name"] == key }
      elsif @doc.is_a?(Hash) && @doc['items'].is_a?(Array)
        obj = @doc['items'].find {|x| x.is_a?(Hash) and x["name"] == key }
      elsif @doc.is_a? Hash
        obj = @doc[key]
      end

      raise NavigationError.new(@doc_resource, key, @doc) unless obj

      if obj.is_a?(Hash) && obj["id"]
        url = obj["id"]
        if @doc_resource
          url          = URI.parse(url.to_s)
        end

        @doc = json_get(url)
      elsif obj.is_a?(Hash) && obj['spec']
        @doc = obj
      elsif obj.is_a?(Hash)
        # No spec string; use parent's and remember extra navigation.
        if @doc['+spec'].is_a?(Array)
          # Something's been added.
          @doc['+spec'] << key
        elsif @doc['+spec'].nil? || @doc['+spec'].is_a?(String)
          @doc['+spec'] = [@doc['spec'], key]
        end
        @doc = obj.merge({'+spec' => @doc['+spec']})
      elsif obj.is_a?(Array)
        # No spec string; use parent's and remember extra navigation.
        if @doc['+spec'].is_a?(Array)
          # Something's already been added.
          @doc['+spec'] << key
        elsif @doc['+spec'].nil? || @doc['+spec'].is_a?(String)
          @doc['+spec'] = [@doc['spec'], key]
        end
        @doc = {'+spec' => @doc['+spec'], 'items' => obj}
      else
        @doc = nil
      end
    end

    def get(url, headers={})
      resource = create_resource(url, headers)
      response = resource.get
      print "GET #{url.to_s}\n#{response.body}\n\n" if @parse.dump_response?
      response
    end

    def json_get(url, headers = {})
      response = get(url,headers.merge(:accept => :json))
      unless response.headers[:content_type] =~ /application\/json/
        raise "Received content type #{response.headers[:content_type]}"
      end
      MultiJson.load(response.body)
    end

    def json_post(url, body)
      headers = {  :accept=>:json, "Content-Type" => :json }
      begin
        resource = create_resource(url, headers)
        response = resource.post MultiJson::dump(body)
      ensure
        if @parse.dump_response?
          print "POST #{url.to_s}\n#{body}\n-->\n"
          puts (response ? response.body : "ERROR")
        end
      end
      MultiJson::load(response.body)
    end

    private

    def create_resource(url, headers)
      @doc_resource = RestClient::Resource.new(url.to_s, :headers => headers,
                                         :verify_ssl => @parse.verify_ssl?,
                                         :user => @username,
                                         :password => @password)
    end
    
    def cmd_schema(cmd_name)
      begin
        json_get(@cmd_url)['schema']
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
end
