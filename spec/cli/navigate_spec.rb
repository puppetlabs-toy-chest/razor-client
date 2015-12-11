# -*- encoding: utf-8 -*-
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
    it { nav.get_document['items'].should == []}

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
      nav = Razor::CLI::Parse.new(['create-broker', '--name', 'broker', '--type', 'puppet', '--configuration', 'not-json']).navigate
      expect{nav.get_document}.to raise_error(ArgumentError, /Invalid object for argument 'configuration'/)
    end

    it "should fail with malformed argument" do
      nav = Razor::CLI::Parse.new(['create-tag', '--name', 'tag_2', '--inva_lid']).navigate
      expect{nav.get_document}.to raise_error(ArgumentError, /Unexpected argument --inva_lid/)
    end
  end

  context "with no parameters", :vcr do
    it "should fail with bad JSON" do
      nav = Razor::CLI::Parse.new(['update-tag-rule']).navigate
      expect{nav.get_document}.to raise_error(Razor::CLI::Error, /No arguments for command/)
    end
  end

  context "with multiple arguments with same name", :vcr do
    context "combining as an array" do
      before(:each) do
        # Prerequisites
        nav = Razor::CLI::Parse.new(['create-repo', '--name', 'name', '--url', 'http://url.com/some.iso', '--task', 'noop']).navigate.get_document
        nav = Razor::CLI::Parse.new(['create-broker', '--name', 'puppet', '--configuration', '{"server": "puppet.example.org", "environment": "production"}', '--broker-type', 'puppet']).navigate.get_document
        nav = Razor::CLI::Parse.new(['create-tag', '--name', 'tag1', '--rule', '["=", ["fact", "processorcount"], "1"]']).navigate.get_document
        nav = Razor::CLI::Parse.new(['create-tag', '--name', 'tag2', '--rule', '["=", ["fact", "processorcount"], "2"]']).navigate.get_document
      end
      it "should merge the arguments as an array" do
        nav = Razor::CLI::Parse.new(['create-policy',
                 '--name', 'test', '--hostname', 'abc.com', '--root-password', 'abc',
                 '--task', 'noop', '--repo', 'name', '--broker', 'puppet', '--tag', 'tag1', '--tag', 'tag2']).navigate
        tags = nav.get_document['tags'].to_s
        tags.should =~ /tag1/
        tags.should =~ /tag2/
      end
      it "should merge the arguments into an existing array" do
        nav = Razor::CLI::Parse.new(['create-policy',
                 '--name', 'test', '--hostname', 'abc.com', '--root-password', 'abc',
                 '--task', 'noop', '--repo', 'name', '--broker', 'puppet', '--tags', '["tag1"]', '--tag', 'tag2']).navigate
        tags = nav.get_document['tags'].to_s
        tags.should =~ /tag1/
        tags.should =~ /tag2/
      end
      it "should merge an array into an existing array" do
        nav = Razor::CLI::Parse.new(['create-policy',
                 '--name', 'test', '--hostname', 'abc.com', '--root-password', 'abc',
                 '--task', 'noop', '--repo', 'name', '--broker', 'puppet', '--tags', '["tag1"]', '--tags', '["tag2"]']).navigate
        tags = nav.get_document['tags'].to_s
        tags.should =~ /tag1/
        tags.should =~ /tag2/
      end
    end
    context "combining as an object" do
      it "should construct a json object" do
        nav = Razor::CLI::Parse.new(['create-broker', '--name', 'broker1', '--broker-type', 'puppet',
                                     '--configuration', 'server=puppet.example.org', '--configuration',
                                     'environment=production']).navigate
        keys = nav.get_document['configuration'].keys
        keys.should include 'server'
        keys.should include 'environment'
      end
      it "should construct a json object with unicode", :preserve_exact_body_bytes do
        doc = Razor::CLI::Parse.new(['register-node', '--installed', 'true', '--hw-info', '{"net0": "abcdef"}']).navigate.get_document
        name = doc['name']
        nav = Razor::CLI::Parse.new(['modify-node-metadata', '--node', name, '--update', 'keyᓱ123=valueᓱ1']).navigate
        nav.get_document['metadata'].should == {'keyᓱ123' => 'valueᓱ1'}
      end
      it "should fail with mixed types (array then hash)" do
        nav = Razor::CLI::Parse.new(['create-broker', '--name', 'broker2', '--broker-type', 'puppet',
                                     '--configuration', '["server"]',
                                     '--configuration', 'environment=production']).navigate
        expect {nav.get_document}.to raise_error(ArgumentError, "Invalid object for argument 'configuration'")
      end
      it "should fail with mixed types (hash then array)" do
        nav = Razor::CLI::Parse.new(['create-broker', '--name', 'broker3', '--broker-type', 'puppet',
                                     '--configuration', 'environment=production',
                                     '--configuration', '["server"]']).navigate
        expect {nav.get_document}.to raise_error(ArgumentError, "Invalid object for argument 'configuration'")
      end
    end
  end

  context "argument formatting", :vcr do
    it "should allow spaces" do
      Razor::CLI::Parse.new(['create-repo', '--name', 'separate with spaces', '--url', 'http://url.com/some.iso', '--task', 'noop']).navigate.get_document
      Razor::CLI::Parse.new(['create-repo', '--name="double-quote with spaces"', '--url', 'http://url.com/some.iso', '--task', 'noop']).navigate.get_document
      Razor::CLI::Parse.new(['create-repo', '--name=\'single-quote with spaces\'', '--url', 'http://url.com/some.iso', '--task', 'noop']).navigate.get_document
    end

    it "should allow '=' in string" do
      Razor::CLI::Parse.new(['create-repo', '--name=\'with=equals\'', '--url', 'http://url.com/some.iso', '--task', 'noop']).navigate.get_document['name'].should =~ /with=equals/
    end

    it "should not allow double-dash with single character flag" do
      nav = Razor::CLI::Parse.new(['create-broker', '--name=some-broker', '--broker-type', 'puppet-pe', '--c', 'server=abc.com']).navigate
      expect{nav.get_document}.to raise_error(ArgumentError, 'Unexpected argument --c (did you mean -c?)')
    end
    it "should not allow single-dash with multiple character flag" do
      nav = Razor::CLI::Parse.new(['create-broker', '--name=some-broker', '-broker-type', 'puppet-pe']).navigate
      expect{nav.get_document}.to raise_error(ArgumentError, 'Unexpected argument -broker-type (did you mean --broker-type?)')
    end
    it "should allow single-dash with single character flag" do
      Razor::CLI::Parse.new(['create-broker', '--name=some-broker', '--broker-type', 'puppet-pe', '-c', 'server=abc.com']).navigate.get_document['configuration']['server'].should == 'abc.com'
    end
  end

  context "positional arguments", :vcr do
    it "should allow the use of positional arguments" do
      Razor::CLI::Parse.new(['create-broker', 'some noop broker', 'noop']).navigate.get_document['name'].should == 'some noop broker'
      Razor::CLI::Parse.new(['create-broker', 'some other broker', '--broker-type', 'noop']).navigate.get_document['name'].should == 'some other broker'
      Razor::CLI::Parse.new(['delete-broker', 'some noop broker']).navigate.get_document['result'].should == 'broker some noop broker destroyed'
      Razor::CLI::Parse.new(['delete-broker', 'some other broker']).navigate.get_document['result'].should == 'broker some other broker destroyed'
    end
    it "should fail with too many positional arguments" do
      nav = Razor::CLI::Parse.new(['create-broker', 'some noop broker', 'noop', 'extra']).navigate
      expect{nav.get_document}.to raise_error(ArgumentError, 'Unexpected argument extra')
    end
  end

  context "for command help", :vcr do
    [['command', '--help'], ['command', '-h'],
     ['--help', 'command'], ['-h', 'command'],
     ['help', 'command'], ['command', 'help']].
    each do |scenario|
      it "should provide command help for `razor #{scenario.join ' '}`" do
        scenario = scenario.map { |name| name.sub('command', 'update-tag-rule') }
        parse = Razor::CLI::Parse.new(scenario)
        nav = parse.navigate
        document = nav.get_document
        document["name"].should == "update-tag-rule"
        document["help"].class.should <= Hash
        parse.should be_show_command_help
      end
    end
  end

  context "with authentication", :vcr do
    AuthArg = %w[-u http://fred:dead@localhost:8150/api].freeze

    it "should supply that to the API service" do
      nav = Razor::CLI::Parse.new(AuthArg).navigate
      nav.get_document.should be_an_instance_of Hash
      nav.last_url.user.should == 'fred'
      nav.last_url.password.should == 'dead'
    end

    it "should preserve that across navigation" do
      nav = Razor::CLI::Parse.new(AuthArg + ['tags']).navigate
      nav.get_document['items'].should == []
      nav.last_url.user.should == 'fred'
      nav.last_url.password.should == 'dead'
    end
  end

  context "with query parameters", :vcr do
    it "should append limit" do
      nav = Razor::CLI::Parse.new(%w[-u http://fred:dead@localhost:8150/api events --limit 1]).navigate
      nav.get_document.should be_an_instance_of Hash
      nav.last_url.to_s.should =~ /limit=1/
    end
    it "should append start" do
      nav = Razor::CLI::Parse.new(%w[-u http://fred:dead@localhost:8150/api events --start 1]).navigate
      nav.get_document.should be_an_instance_of Hash
      nav.last_url.to_s.should =~ /start=1/
    end
    it "should throw an error if the query parameter is not in the API" do
      nav = Razor::CLI::Parse.new(%w[-u http://fred:dead@localhost:8150/api events --not-in-api 1]).navigate
      expect {nav.get_document}.to raise_error(OptionParser::InvalidOption, 'invalid option: --not-in-api')
    end
    it "should not fail when query returns details for one item" do
      nav = Razor::CLI::Parse.new(['register-node', '--installed', 'true', '--hw-info', 'net0=78:31:c1:be:c8:00']).navigate.get_document
      name = nav['name']
      nav = Razor::CLI::Parse.new(['-u', 'http://fred:dead@localhost:8150/api', 'nodes', name]).navigate
      nav.get_document['name'].should == name
    end
    it "should throw an error if the query parameter is not in the API from a single item" do
      nav = Razor::CLI::Parse.new(['register-node', '--installed', 'true', '--hw-info', 'net0=78:31:c1:be:c8:00']).navigate.get_document
      name = nav['name']
      expect {Razor::CLI::Parse.new(['-u', 'http://fred:dead@localhost:8150/api', 'nodes', name, '--limit', '1']).
          navigate.get_document}.to raise_error(OptionParser::InvalidOption, 'invalid option: --limit')
    end
    it "should store query without query parameters" do
      name = Razor::CLI::Parse.new(['register-node', '--installed', 'true', '--hw-info', 'net0=78:31:c1:be:c8:00']).
          navigate.get_document['name']
      Razor::CLI::Parse.new(['register-node', '--installed', 'true', '--hw-info', 'net0=78:31:c1:be:c8:01']).
          navigate.get_document
      parse = Razor::CLI::Parse.new(['-u', 'http://fred:dead@localhost:8150/api', 'nodes', name, 'log', '--limit', '1'])
      parse.navigate.get_document
      parse.stripped_args.should == ['nodes', name, 'log']
    end
  end
end
