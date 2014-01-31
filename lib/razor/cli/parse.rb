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

        opts.on "-u", "--url URL",
          "The full Razor API URL, can also be set\n" + " "*37 +
          "with the RAZOR_API environment variable\n" + " "*37 +
          "(default #{DEFAULT_RAZOR_API})" do |url|
          parse_and_set_api_url(url, :opts)
        end

        opts.on "-h", "--help", "Show this screen" do
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

    def help
      output = get_optparse.to_s
      begin
        output << list_things("Collections", navigate.collections)
        output << "\n\n      Navigate to entries of a collection using COLLECTION NAME, for example,\n      'nodes node15'  for the  details of a node or 'nodes node15 log' to see\n      the log for node15\n"
        output << list_things("Commands", navigate.commands)
        output << "\n\n      Pass arguments to commands either directly by name ('--name=NAME')\n      or save the JSON body for the  command  in a file and pass it with\n      '--json FILE'.  Using --json is the only way to pass  arguments in\n      nested structures such as the configuration for a broker.\n"
      rescue
        output << "\nCould not connect to the server at #{@api_url}. More help is available after "
        output << "pointing\nthe client to a Razor server"
      end
      output
    end

    def show_help?
      !!@option_help
    end

    def dump_response?
      !!@dump
    end

    attr_reader :api_url

    def initialize(args)
      parse_and_set_api_url(ENV["RAZOR_API"] || DEFAULT_RAZOR_API, :env)
      @args = args.dup
      rest = get_optparse.order(args)
      if rest.any?
        @navigation = rest
      else
        @option_help = true
      end
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
