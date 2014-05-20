require 'uri'
require 'optparse'

module Razor::CLI

  class Parse
    DEFAULT_RAZOR_API = "http://localhost:8080/api"

    def get_optparse
      @optparse ||= OptionParser.new do |opts|
        opts.banner = "Usage: razor [FLAGS] NAVIGATION\n"

        opts.on "-d", "--dump", "Dumps API output to the screen" do
          @dump = true
        end

        opts.on "-f", "--full", "Show full details when viewing entities" do
          @format = 'full'
        end

        opts.on "-s", "--short", "Show shortened details when viewing entities" do
          @format = 'short'
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
      <<-VERSION
Razor Server version: #{navigate.server_version}
Razor Client version: #{Razor::CLI::VERSION}
      VERSION
    end

    def help
      output = get_optparse.to_s
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
      rescue
        output << <<-ERR
Error: Could not connect to the server at #{@api_url}. More help is available after pointing
the client to a Razor server
ERR
      end
      output
    end

    def show_version?
      !!@show_version
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

    attr_reader :api_url, :format, :args

    def initialize(args)
      parse_and_set_api_url(ENV["RAZOR_API"] || DEFAULT_RAZOR_API, :env)
      @args = args.dup
      @format = 'short'
      rest = get_optparse.order(args)
      rest = set_help_vars(rest)
      if rest == ['version'] or @show_version
        @show_version = true
      elsif rest.any?
        @navigation = rest
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
        @api_url = URI.parse(url)
      rescue URI::InvalidURIError => e
        raise Razor::CLI::InvalidURIError.new(url, source)
      end
    end
  end
end
