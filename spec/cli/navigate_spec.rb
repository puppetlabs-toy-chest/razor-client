# Needed to make the client work on Ruby 1.8.7
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative '../spec_helper'

describe Razor::CLI::Navigate do
  context "with no path", :vcr do
    subject(:nav) {Razor::CLI::Parse.new([]).navigate}
    it do
      nav.get_document.should_not be_nil
      nav.get_document.should == nav.entrypoint
    end
  end

  context "with a single item path", :vcr do
    subject(:nav) {Razor::CLI::Parse.new(["tags"]).navigate}
    it { nav.get_document.should == []}

    it do
      nav.get_document;
      nav.last_url.to_s.should =~ %r{/api/collections/tags$}
    end
  end

  context "with an invalid path", :vcr do
    subject(:nav) {Razor::CLI::Parse.new(["going","nowhere"]).navigate}

    it {expect{nav.get_document}.to raise_error Razor::CLI::NavigationError}
  end

  context "with invalid parameter", :vcr do
    it "should fail with bad JSON" do
      nav = Razor::CLI::Parse.new(['update-tag-rule', '--name', 'tag_1', '--rule', 'not-json']).navigate
      expect{nav.get_document}.to raise_error(ArgumentError, /Invalid JSON for argument 'rule'/)
    end
  end

  context "with authentication", :vcr do
    AuthArg = %w[-u http://fred:dead@localhost:8080/api].freeze

    it "should supply that to the API service" do
      nav = Razor::CLI::Parse.new(AuthArg).navigate
      nav.get_document.should be_an_instance_of Hash
      URI.parse(nav.last_url.to_s).userinfo.should == "fred:dead"
    end

    it "should preserve that across navigation" do
      nav = Razor::CLI::Parse.new(AuthArg + ['tags']).navigate
      nav.get_document.should == []
      URI.parse(nav.last_url.to_s).userinfo.should == "fred:dead"
    end
  end
end
