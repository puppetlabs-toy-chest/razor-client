require 'rest-client'
require 'multi_json'
require 'yaml'
require 'forwardable'

# Needed to make the client work on Ruby 1.8.7
unless URI.respond_to?(:encode_www_form)
  module URI
    def self.encode_www_form_component(str)
      str = str.to_s
      if HTML5ASCIIINCOMPAT.include?(str.encoding)
        str = str.encode(Encoding::UTF_8)
      else
        str = str.dup
      end
      str.force_encoding(Encoding::ASCII_8BIT)
      str.gsub!(/[^*\-.0-9A-Z_a-z]/, TBLENCWWWCOMP_)
      str.force_encoding(Encoding::US_ASCII)
    end
    def self.encode_www_form(enum)
      enum.map do |k,v|
        if v.nil?
          encode_www_form_component(k)
        elsif v.respond_to?(:to_ary)
          v.to_ary.map do |w|
            str = encode_www_form_component(k)
            unless w.nil?
              str << '='
              str << encode_www_form_component(w)
            end
          end.join('&')
        else
          str = encode_www_form_component(k)
          str << '='
          str << encode_www_form_component(v)
        end
      end.join('&')
    end
  end
end

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
      elsif @doc.is_a? Hash
        obj = @doc[key]
      end

      raise NavigationError.new(@doc_resource, key, @doc) unless obj

      if obj.is_a?(Hash) && obj["id"]
        url = URI.parse(obj["id"])

        @doc = json_get(url, {}, params)
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

    def json_get(url, headers = {}, params = {})
      # Add extra parameters to URL.
      url.query = URI.encode_www_form(params)
      url.query = nil if url.query.empty? # Remove dangling '?' from URL.

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
                                         :ssl_ca_file      =>  @parse.ssl_ca_file,
                                         :user => @username,
                                         :password => @password)
    end
  end
end
