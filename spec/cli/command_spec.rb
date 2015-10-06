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

describe Razor::CLI::Command do
  Command = Razor::CLI::Command
  # let(:inst) { Class.new { include Razor::CLI::Command } }

  let :existing_value do nil end

  context "convert_arg" do
    it "performs no conversion for 'json' reserved argument name" do
      value = '/some/path'
      cmd_schema = {'json' => {'type' => 'number', 'aliases' => ['b']}}
      result = Command.convert_arg('json', value, existing_value, cmd_schema)
      result.should == '/some/path'
    end

    [['number', '123', 123], ['array', '[1, 2]', [1, 2]], ['array', '1', [1]],
     ['object', '{"abc":123}', {'abc' => 123}], ['object', 'abc=123', {'abc' => '123'}]].
        each do |type, orig, final|
      it "finds the right datatype for #{type} #{orig}" do
        cmd_schema = {"tags"=>{"type"=>"#{type}"}}
        result = Command.convert_arg('tags', orig, existing_value, cmd_schema)
        result.should == final
      end
    end
    it "returns argument as-is when it cannot find the datatype" do
      cmd_schema = {"tags"=>{}}
      result = Command.convert_arg('tags', 'abc', existing_value, cmd_schema)
      result.should == 'abc'
    end
    it "appends to existing values" do
      cmd_schema = {"tags"=>{'type' => 'array'}}
      existing_value = ['abc']
      result = Command.convert_arg('tags', 'def', existing_value, cmd_schema)
      result.should == %w(abc def)
    end
  end

  context "resolve_alias" do
    it "resolves the alias when alias is present" do
      cmd_schema = {'def' => {'type' => 'array', 'aliases' => ['abc']}}
      result = Command.resolve_alias('abc', cmd_schema)
      result.should == 'def'
    end
    it "leaves name alone when alias is present" do
      cmd_schema = {'def' => {'type' => 'array', 'aliases' => ['abc']}}
      result = Command.resolve_alias('ghi', cmd_schema)
      result.should == 'ghi'
    end
    it "leaves name alone when no alias is present" do
      cmd_schema = {'def' => {'type' => 'array'}}
      result = Command.resolve_alias('abc', cmd_schema)
      result.should == 'abc'
    end
  end

  context "extract_command" do
    it "fails with a single dash for long flags" do
      c = Razor::CLI::Command.new(nil, nil, {'schema' => {'name' => {'type' => 'array'}}},
                                  ['-name', 'abc'], '/foobar')
      expect{c.extract_command}.
          to raise_error(ArgumentError, 'Unexpected argument -name')
    end
    it "fails with a double dash for short flags" do
      c = Razor::CLI::Command.new(nil, nil, {'schema' => {'n' => {'type' => 'array'}}},
                                  ['--n', 'abc'], '/foobar')
      expect{c.extract_command}.
          to raise_error(ArgumentError, 'Unexpected argument --n')
    end
    it "fails with a double dash for short flags if argument does not exist" do
      c = Razor::CLI::Command.new(nil, nil, {'schema' => {}},
                                  ['--n', 'abc'], '/foobar')
      expect{c.extract_command}.
          to raise_error(ArgumentError, 'Unexpected argument --n')
    end
    it "succeeds with a double dash for long flags" do
      c = Razor::CLI::Command.new(nil, nil, {'schema' => {'name' => {'type' => 'array'}}},
                                  ['--name', 'abc'], '/foobar')
      c.extract_command['name'].should == ['abc']
    end
    it "succeeds with a single dash for short flags" do
      c = Razor::CLI::Command.new(nil, nil, {'schema' => {'n' => {'type' => 'array'}}},
                                  ['-n', 'abc'], nil)
      c.extract_command['n'].should == ['abc']
    end
  end
end