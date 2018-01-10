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
      @doc_resource = create_resource parse.api_url, {:accept => :json,
                                                      :accept_language => accept_language}
    end

    attr_accessor :doc_resource

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
      entrypoint.has_key?('version') and entrypoint['version']['server'] or _('Unknown')
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
        Razor::CLI::Query.new(@parse, self, collections, @segments).run
      elsif command?
        cmd = @segments.shift
        command = commands.find { |coll| coll["name"] == cmd }
        cmd_url = URI.parse(command['id'])
        # Ensure that we copy authentication data from our previous URL.
        if @doc_resource
          cmd_url = URI.parse(cmd_url.to_s)
        end
        command = json_get(cmd_url)
        Razor::CLI::Command.new(@parse, self, command, @segments, cmd_url).run
      else
        raise NavigationError.new(@doc_resource, @segments, @doc)
      end
    end

    def move_to(key, doc = @doc, params = {})
      @doc = doc
      if @doc.is_a? Array
        obj = @doc.find {|x| x.is_a?(Hash) and x["name"] == key }
      elsif @doc.is_a?(Hash) && @doc['items'].is_a?(Array)
        obj = @doc['items'].find {|x| x.is_a?(Hash) and x["name"] == key }
      elsif @doc.is_a?(Hash)
        obj = @doc[key]
      end

      raise NavigationError.new(@doc_resource, key, @doc) if obj.nil?

      if obj.is_a?(Hash) && obj["id"]
        url = URI.parse(obj["id"])

        @doc = json_get(url, {}, params)
      elsif obj.is_a?(Hash) && obj['spec']
        @doc = obj
      elsif obj.is_a?(Hash) || obj.is_a?(Array)
        # We have reached a data structure that doesn't have a spec string!
        # This means we should use the parent's string and keep track of which
        # extra navigation is needed, so we can still format the data
        # accordingly.
        if @doc['+spec'].is_a?(Array)
          # Something's been added.
          @doc['+spec'] << key
        elsif @doc['+spec'].nil? || @doc['+spec'].is_a?(String)
          @doc['+spec'] = [@doc['spec'], key]
        end
        @doc = obj.merge({'+spec' => @doc['+spec']}) if obj.is_a?(Hash)
        @doc = {'+spec' => @doc['+spec'], 'items' => obj} if obj.is_a?(Array)
        @doc
      else
        @doc = obj
      end
    end

    def accept_language
      @accept_language ||= GettextSetup.candidate_locales
    end

    def get(url, headers={})
      resource = create_resource(url, headers)
      response = resource.get
      print "GET #{url.to_s}\n#{response.body}\n\n" if @parse.dump_response?
      response
    end

    def json_get(url, headers = {}, params = {})
      # Add extra parameters to URL.
      url.query = URI.encode_www_form(params)
      url.query = nil if url.query.empty? # Remove dangling '?' from URL.
      @username ||= url.user
      @password ||= url.password

      response = get(url,headers.merge(:accept => :json,
                                       :accept_language => accept_language))
      unless response.headers[:content_type] =~ /application\/json/
        raise _("Received content type %{content_type}") % {content_type: response.headers[:content_type]}
      end
      MultiJson.load(response.body)
    end

    def json_post(url, body)
      @username ||= url.user
      @password ||= url.password

      headers = { :accept=>:json, "Content-Type" => :json,
                  :accept_language => accept_language}
      begin
        resource = create_resource(url, headers)
        response = resource.post MultiJson::dump(body)
      ensure
        if @parse.dump_response?
          print "POST #{url.to_s}\n#{body}\n-->\n"
          puts (response ? response.body : _("ERROR"))
        end
      end
      MultiJson::load(response.body)
    end

    private

    def create_resource(url, headers)
      @doc_resource = RestClient::Resource.new(url.to_s,
          :headers => headers,
          :verify_ssl => @parse.verify_ssl?,
          :ssl_ca_file => @parse.ssl_ca_file,
          # Add these in case the URL above doesn't include authentication.
          :user => @username || url.user,
          :password => @password || url.password)
    end
  end
end
