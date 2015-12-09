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
      it {parse.verify_ssl?.should be false}
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
        parse('-u',url).verify_ssl?.should == true
      end

      it "should respect insecure requests" do
        url = 'http://razor.example.com:2150/path/to/api'
        parse('-u',url,'-k').verify_ssl?.should be false
      end

      it "should terminate with an error if an invalid URL is provided" do
        expect{parse('-u','not valid url')}.to raise_error(Razor::CLI::InvalidURIError)
      end

      it "should terminate with an error if a URL without a protocol is provided" do
        expect{parse('-u','localhost:8151/api')}.to raise_error(Razor::CLI::InvalidURIError)
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

    context "with '--version'" do
      it {parse("--version").show_version?.should be true}
    end

    context "with '--version' and no reachable server" do
      subject { parse("--version", '-u', 'https://localhost:9999999/api').version.first }
      it { should =~ /Razor Server version: \(unknown\)/ }
      it { should =~ /Razor Client version: #{Razor::CLI::VERSION}/ }
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

    context "with ENV RAZOR_CA_FILE set" do
      after :each do
        ENV::delete('RAZOR_CA_FILE')
      end
      it "should raise an error if the RAZOR_CA_FILE override is invalid" do
        ENV['RAZOR_CA_FILE'] = '/does/not/exist'
        expect{parse}.to raise_error(Razor::CLI::InvalidCAFileError,
            "CA file '/does/not/exist' in ENV variable RAZOR_CA_FILE does not exist")
      end
    end

    describe "#help", :vcr do
      subject(:p) {parse}
      it { should respond_to :help}

      it { output, exitcode = p.help
           output.should be_a String
           exitcode.should == 0}

      it "should print a list of known endpoints" do
        p.navigate.should_receive(:collections).and_return([])
        p.navigate.should_receive(:commands).and_return([])
        _, exitcode = p.help
        exitcode.should == 0
      end
    end
  end
end
