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
      @doc_url = parse.api_url
    end

    def last_url
      @doc_url
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

    def query?
      collections.any? { |coll| coll["name"] == @segments.first }
    end

    def command(name)
      commands.find { |coll| coll["name"] == name }
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
            item.has_key?('id') ? json_get(item['id']) : item
          end
        end
        @doc
      elsif command?
        # @todo lutter 2013-08-16: None of this has any tests, and error
        # handling is heinous at best
        cmd, body = extract_command
        # Ensure that we copy authentication data from our previous URL.
        url = cmd["id"]
        if @doc_url
          url          = URI.parse(url.to_s)
          url.userinfo = @doc_url.userinfo
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
        raise NavigationError.new(@doc_url, @segments, @doc)
      end
    end

    def extract_command
      cmd = command(@segments.shift)
      body = {}
      until @segments.empty?
        argument = @segments.shift
        if argument =~ /\A--([a-z-]+)(=(\S+))?\Z/
          arg, value = [$1, $3]
          value = @segments.shift if value.nil? && @segments[0] !~ /^--/
          body[arg] = convert_arg(cmd["name"], arg, value)
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

      raise NavigationError.new(@doc_url, key, @doc) unless obj

      if obj.is_a?(Hash) && obj["id"]
        url = obj["id"]
        if @doc_url
          url          = URI.parse(url.to_s)
          url.userinfo = @doc_url.userinfo
        end

        @doc = json_get(url)
        @doc_url = url
      elsif obj.is_a? Hash
        @doc = obj
      else
        @doc = nil
      end
    end

    def get(url, headers={})
      response = RestClient.get url.to_s, headers
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
        response = RestClient.post url.to_s, MultiJson::dump(body), headers
      ensure
        if @parse.dump_response?
          print "POST #{url.to_s}\n#{body}\n-->\n"
          puts (response ? response.body : "ERROR")
        end
      end
      MultiJson::load(response.body)
    end

    private
    def self.annotations
      @@annotations ||=
        YAML::load_file(File::join(File::dirname(__FILE__), "navigate.yaml"))
    end

    def self.arg_type(cmd_name, arg_name)
      cmd = annotations["commands"][cmd_name]
      cmd && cmd["args"][arg_name]
    end

    def convert_arg(cmd_name, arg_name, value)
      value = nil if value == "null"
      case self.class.arg_type(cmd_name, arg_name)
        when "json"
          begin
            MultiJson::load(value)
          rescue MultiJson::LoadError => error
            raise ArgumentError, "Invalid JSON for argument '#{arg_name}': #{error.message}"
          end
        when "boolean"
          ["true", nil].include?(value)
        when "integer"
          begin
            Integer(value)
          rescue ArgumentError
            raise ArgumentError, "Invalid integer for argument '#{arg_name}': #{value}"
          end
        when "reference"
          begin
            MultiJson::load(value)
          rescue MultiJson::LoadError
            { "name" => value }
          end
        else
          value
      end
    end
  end
end
