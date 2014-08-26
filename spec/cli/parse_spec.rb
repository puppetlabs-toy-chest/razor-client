# Needed to make the client work on Ruby 1.8.7
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require "rspec/expectations"
require_relative '../spec_helper'

describe Razor::CLI::Parse do

  def parse(*args)
    Razor::CLI::Parse.new(args)
  end

  describe "#new" do
    context "with no arguments" do
      it {parse.show_help?.should be true}
      it {parse.verify_ssl?.should be true}
    end

    context "with a '-h'" do
      it {parse("-h").show_help?.should be true}
    end

    context "with a '-h COMMAND'" do
      it {parse("-h", "create-policy").show_command_help?.should be true}
    end

    context "with a '--help COMMAND'" do
      it {parse("--help", "create-policy").show_command_help?.should be true}
    end

    context "with a 'help COMMAND'" do
      it {parse("help", "create-policy").show_command_help?.should be true}
    end

    context "with a 'help COMMAND'" do
      it {parse("create-policy", "help").show_command_help?.should be true}
    end

    context "with a 'COMMAND var help'" do
      it {parse("create-policy", "var", "help").show_command_help?.should_not be true}
    end

    context "with a '-d'" do
      it {parse("-d").dump_response?.should be true}
    end

    context "with a '-u'" do
      it "should use the given URL" do
        url = 'http://razor.example.com:2150/path/to/api'
        parse('-u',url).api_url.to_s.should == url
      end

      it "should terminate with an error if an invalid URL is provided" do
        expect{parse('-u','not valid url')}.to raise_error(Razor::CLI::InvalidURIError)
      end
    end

    context "with a '-k'" do
      it {parse("-k").verify_ssl?.should be false}
    end

    context "with an '-a'" do
      it {parse("-a").show_api_help?.should be true}
    end

    context "with an '--api'" do
      it {parse("--api").show_api_help?.should be true}
    end

    context "with a '--insecure'" do
      it {parse("--insecure").verify_ssl?.should be false}
    end

    context "with ENV RAZOR_API set" do
      it "should use the given URL" do
        url = 'http://razor.example.com:2150/env/path/to/api'
        ENV["RAZOR_API"] = url
        parse.api_url.to_s.should == url
      end

      it "should use -u before ENV" do
        env_url = 'http://razor.example.com:2150/env/path/to/api'
        url = 'http://razor.example.com:2150/path/to/api'
        ENV["RAZOR_API"] = env_url
        parse('-u',url).api_url.to_s.should == url
      end

      it "should terminate with an error if an invalid URL is provided" do
        ENV["RAZOR_API"] = 'not valid url'
        expect{parse}.to raise_error(Razor::CLI::InvalidURIError)
      end
    end

    describe "#help", :vcr do
      subject(:p) {parse}
      it { should respond_to :help}

      it { p.help.should be_a String}

      it "should print a list of known endpoints" do
        p.navigate.should_receive(:collections).and_return([])
        p.navigate.should_receive(:commands).and_return([])
        p.help
      end
    end
  end
end
