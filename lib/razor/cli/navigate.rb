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
          if value =~ /\A(.+?)=(\S+)?\z/
            # `--arg name=value`
            unless body[arg].nil? or body[arg].is_a?(Hash)
              # Error: `--arg value --arg name=value`
              raise ArgumentError, "Cannot handle mixed types for argument #{arg}"
            end
            # Do not convert, assume the above is the conversion.
            body[arg] = (body[arg].nil? ? {} : body[arg]).merge($1 => $2)
          elsif body[arg].is_a?(Hash)
            # Error: `--arg name=value --arg value`
            raise ArgumentError, "Cannot handle mixed types for argument #{arg}"
          else
            value = convert_arg(cmd["name"], arg, value)
            if body[arg].nil?
              body[arg] = value
            else
              # Either/both `body[arg]` or/and `value` might be an array at this point.
              body[arg] = Array(body[arg]) + Array(value)
            end
          end
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

    def convert_arg(cmd_name, arg_name, value)
      value = nil if value == "null"

      argument_type = arg_type(cmd_name, arg_name)

      # This might be helpful, since there's no other method for debug-level logging on the client.
      puts "Formatting argument #{arg_name} with value #{value} as #{argument_type}\n" if @parse.dump_response?

      case argument_type
        when "array"
          # 'array' datatype arguments will never fail. At worst, they'll be wrapped in an array.
          begin
            MultiJson::load(value)
          rescue MultiJson::LoadError => _
            Array(value)
          end
        when "object"
          begin
            MultiJson::load(value)
          rescue MultiJson::LoadError => error
            raise ArgumentError, "Invalid JSON for argument '#{arg_name}': #{error.message}"
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
