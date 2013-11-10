require "rspec/expectations"
require_relative '../spec_helper'

describe Razor::CLI::Parse do

  def parse(*args)
    Razor::CLI::Parse.new(args)
  end

  describe "#new" do
    context "with no arguments" do
      it {parse.show_help?.should be true}
    end

    context "with a '-h'" do
      it {parse("-h").show_help?.should be true}
    end

    context "with a '-d'" do
      it {parse("-d").dump_response?.should be true}
    end

    context "with a '-U'" do
      it "should use the given URL" do
        url = 'http://razor.example.com:2150/path/to/api'
        parse('-U',url).api_url.to_s.should == url
      end

      it "should terminate with an error if an invalid URL is provided" do
        expect{parse('-U','not valid url')}.to raise_error(Razor::CLI::InvalidURIError)
      end
    end

    context "with ENV RAZOR_API set" do
      it "should use the given URL" do
        url = 'http://razor.example.com:2150/env/path/to/api'
        ENV["RAZOR_API"] = url
        parse.api_url.to_s.should == url
      end

      it "should use -U before ENV" do
        env_url = 'http://razor.example.com:2150/env/path/to/api'
        url = 'http://razor.example.com:2150/path/to/api'
        ENV["RAZOR_API"] = env_url
        parse('-U',url).api_url.to_s.should == url
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
