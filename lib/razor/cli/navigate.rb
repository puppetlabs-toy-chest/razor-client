require 'rest-client'
require 'multi_json'
require 'yaml'
require 'forwardable'

module Razor::CLI
  class Navigate
    RAZOR_HTTPS_API = "https://localhost:8151/api"
    RAZOR_HTTP_API = "http://localhost:8150/api"
    extend Forwardable

    def initialize(parse, segments)
      @parse = parse
      @segments = segments||[]
      set_api_url!(parse)
      @doc = entrypoint
      @doc_resource = create_resource parse.api_url, {:accept => :json,
                                               :accept_language => accept_language}
    end

    # This returns an array of two elements:
    # - The URL that, if neither the `-u` argument nor the
    #   RAZOR_API environment variable are set, will be used.
    # - The source from which the URL was found, `:https` or `:http`.
    def default_api
      if https_api_exists?
        [RAZOR_HTTPS_API, :https]
      else
        [RAZOR_HTTP_API, :http]
      end
    end

    # The order of API selection works as follows:
    # - Use `-u` argument if defined (done elsewhere)
    # - Use "RAZOR_API" environment variable if defined
    # - Check PE's https://localhost:8151/api via `HEAD` HTTP method
    # - Use FOSS' http://localhost:8150/api
    # This receives an argument determining whether to be verbose about
    # requests made.
    def set_api_url!(parse)
      if !!parse.api_url
        parse.api_url.to_s
      elsif ENV["RAZOR_API"]
        parse.parse_and_set_api_url(ENV['RAZOR_API'], :env)
      else
        url, source = default_api
        parse.parse_and_set_api_url(url, source)
      end
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

    def head(url, headers={})
      resource = create_resource(url, headers)
      response = resource.head
      print "HEAD #{url.to_s}\n#{response.body}\n\n" if @parse.dump_response?
      response
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
    def https_api_exists?
      # No need to verify SSL on localhost, cert won't match.
      old_verify_ssl = @parse.verify_ssl?
      @parse.verify_ssl = false
      begin
        url = RAZOR_HTTPS_API
        head(URI.parse(url))
      rescue Errno::ENOENT, Errno::ECONNREFUSED
        false
      ensure
        print "HEAD #{url.to_s}\n\n" if @parse.dump_response?
        @parse.verify_ssl = old_verify_ssl
      end
    end

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
