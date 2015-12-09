require 'uri'
require 'optparse'
require 'forwardable'

# Needed to make the client work on Ruby 1.8.7
unless URI::Generic.method_defined?(:hostname)
  module URI
    def hostname
      v = self.host
      /\A\[(.*)\]\z/ =~ v ? $1 : v
    end
  end
end

module Razor::CLI

  class Parse
    extend Forwardable
    DEFAULT_RAZOR_API = "http://localhost:8150/api"

    def_delegator 'navigate', 'query?'

    def get_optparse
      @optparse ||= OptionParser.new do |opts|
        opts.banner = "Usage: razor [FLAGS] NAVIGATION\n"

        opts.on "-d", "--dump", "Dumps API output to the screen" do
          @dump = true
        end

        opts.on "-a", "--api", "Show API help for a command" do
          @api_help = true
        end

        opts.on "-k", "--insecure", "Allow SSL connections without verified certificates" do
          @verify_ssl = false
        end

        opts.on "-u", "--url URL",
          "The full Razor API URL, can also be set\n" + " "*37 +
          "with the RAZOR_API environment variable\n" + " "*37 +
          "(default #{DEFAULT_RAZOR_API})" do |url|
          parse_and_set_api_url(url, :opts)
        end

        opts.on "-v", "--version", "Show the version of Razor" do
          @show_version = true
        end

        opts.on "-h", "--help", "Show this screen" do
          # If searching for a command's help, leave the argument for navigation.
          @option_help = true
        end

      end
    end

    def list_things(name, items)
      "\n    #{name}:\n" +
        items.map {|x| x["name"]}.compact.sort.map do |name|
        "        #{name}"
      end.join("\n")
    end

    def version
      server_version = '(unknown)'
      error = ''
      begin
        server_version = navigate.server_version
      rescue RestClient::Unauthorized
        error = "Error: Credentials are required to connect to the server at #{@api_url}."
      rescue
        error = "Error: Could not connect to the server at #{@api_url}."
      ensure
        return [(<<-OUTPUT + "\n" + error).rstrip, error != '' ? 1 : 0]
        Razor Server version: #{server_version}
        Razor Client version: #{Razor::CLI::VERSION}
        OUTPUT
      end
    end

    def help
      output = get_optparse.to_s
      exit = 0
      begin
        output << <<-HELP
#{list_things("Collections", navigate.collections)}

      Navigate to entries of a collection using COLLECTION NAME, for example,
      'nodes node15'  for the  details of a node or 'nodes node15 log' to see
      the log for node15
#{list_things("Commands", navigate.commands)}

      Pass arguments to commands either directly by name ('--name=NAME')
      or save the JSON body for the  command  in a file and pass it with
      '--json FILE'.  Using --json is the only way to pass  arguments in
      nested structures such as the configuration for a broker.

HELP
      rescue RestClient::Unauthorized
        output << <<-UNAUTH
Error: Credentials are required to connect to the server at #{@api_url}"
UNAUTH
        exit = 1
      rescue SocketError, Errno::ECONNREFUSED => e
        puts "Error: Could not connect to the server at #{@api_url}"
        puts "       #{e}\n"
        die
      rescue RestClient::SSLCertificateNotVerified
        puts "Error: SSL certificate could not be verified against known CA certificates."
        puts "       To turn off verification, use the -k or --insecure option."
        die
      rescue OpenSSL::SSL::SSLError => e
        # Occurs in case of e.g. certificate mismatch (FQDN vs. hostname)
        puts "Error: SSL certificate error from server at #{@api_url}"
        puts "       #{e}"
        die
      rescue => e
        output << <<-ERR
Error: Unknown error occurred while connecting to server at #{@api_url}:
       #{e}
ERR
        exit = 1
      end
      [output, exit]
    end

    def show_version?
      !!@show_version
    end

    def show_api_help?
      !!@api_help
    end

    def show_help?
      !!@option_help
    end

    def show_command_help?
      !!@command_help
    end

    def dump_response?
      !!@dump
    end

    def verify_ssl?
      !!@verify_ssl
    end

    attr_reader :api_url, :args
    # The format can be determined from later segments.
    attr_accessor :format, :stripped_args, :ssl_ca_file

    LINUX_PEM_FILE = '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
    WIN_PEM_FILE = 'C:\ProgramData\PuppetLabs\puppet\etc\ssl\certs\ca.pem'
    def initialize(args)
      parse_and_set_api_url(ENV["RAZOR_API"] || DEFAULT_RAZOR_API, :env)
      @args = args.dup
      # To be populated externally.
      @stripped_args = []
      @format = 'short'
      @verify_ssl = true
      env_pem_file = ENV['RAZOR_CA_FILE']
      # If this is set, it should actually exist.
      if env_pem_file && !File.exists?(env_pem_file)
        raise Razor::CLI::InvalidCAFileError.new(env_pem_file)
      end
      pem_file_locations = [env_pem_file, LINUX_PEM_FILE, WIN_PEM_FILE]
      pem_file_locations.each do |file|
        if file && File.exists?(file)
          @ssl_ca_file = file
          break
        end
      end
      @args = get_optparse.order(@args)

      # Localhost won't match the server's certificate; no verification required.
      # This needs to happen after get_optparse so `-k` and `-u` can take effect.
      if @api_url.hostname == 'localhost'
        @verify_ssl = false
      end

      @args = set_help_vars(@args)
      if @args == ['version'] or @show_version
        @show_version = true
      elsif @args.any?
        @navigation = @args.dup
      else
        # Called with no remaining arguments to parse.
        @option_help = true
      end
    end

    # This method sets the appropriate help flags `@command_help` and `@option_help`,
    # then returns a new set of arguments.
    def set_help_vars(rest)
      # Find and remove 'help' variations anywhere in the command.
      if rest.any? { |arg| ['-h', '--help'].include? arg } or
          rest.first == 'help' or rest.drop(1).first == 'help'
        rest = rest.reject { |arg| ['-h', '--help', 'help'].include? arg }
        # If anything is left, assume it is a command.
        if rest.any?
          @command_help = true
        else
          @option_help = true
        end
      end
      if @option_help && rest.any?
        @command_help = true
      end
      rest
    end

    def navigate
      @navigate ||=Navigate.new(self, @navigation)
    end

    private
    def parse_and_set_api_url(url, source)
      begin
        unless url.start_with?('http:') or url.start_with?('https:')
          raise Razor::CLI::InvalidURIError.new(url, source)
        end
        @api_url = URI.parse(url)
      rescue URI::InvalidURIError => e
        raise Razor::CLI::InvalidURIError.new(url, source)
      end
    end
  end
end
