require 'uri'
require 'optparse'

module Razor::CLI

  class Parse
    DEFAULT_RAZOR_API = "http://localhost:8080/api"

    def get_optparse
      @optparse ||= OptionParser.new do |opts|
        opts.banner = "Usage: razor [FLAGS] NAVIGATION\n"
                      "   or: razor shell"

        opts.on "-d", "--dump", "Dumps API output to the screen" do
          @dump = true
        end

        opts.on "-U", "--url URL",
          "The full Razor API URL, can also be set\n" + " "*37 +
          "with the RAZOR_API environment variable\n" + " "*37 +
          "(default #{DEFAULT_RAZOR_API})" do |url|
          @api_url = URI.parse(url)
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
        output << list_things("collections", navigate.collections)
        output << list_things("commands", navigate.commands)
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
      @api_url = URI.parse(ENV["RAZOR_API"] || DEFAULT_RAZOR_API)
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
  end
end
