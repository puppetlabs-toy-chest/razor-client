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

    def extract(schema, run_array)
      c = Razor::CLI::Command.new(nil, nil, schema, run_array, nil)
      c.extract_command
    end
    context "flag length" do

      it "fails with a single dash for long flags" do
        expect{extract({'schema' => {'name' => {'type' => 'array'}}}, ['-name', 'abc'])}.
            to raise_error(ArgumentError, 'Unexpected argument -name (did you mean --name?)')
      end
      it "fails with a double dash for short flags" do
        expect{extract({'schema' => {'n' => {'type' => 'array'}}}, ['--n', 'abc'])}.
            to raise_error(ArgumentError, 'Unexpected argument --n (did you mean -n?)')
      end
      it "fails with a double dash for short flags if argument does not exist" do
        c = Razor::CLI::Command.new(nil, nil, {'schema' => {}},
                                    ['--n', 'abc'], '/foobar')
        expect{extract({'schema' => {}}, ['--n', 'abc'])}.
            to raise_error(ArgumentError, 'Unexpected argument --n')
      end
      it "succeeds with a double dash for long flags" do
        extract({'schema' => {'name' => {'type' => 'array'}}},
                ['--name', 'abc'])['name'].should == ['abc']
      end
      it "succeeds with a single dash for short flags" do
        c = Razor::CLI::Command.new(nil, nil, {'schema' => {'n' => {'type' => 'array'}}},
                                    ['-n', 'abc'], nil)
        extract({'schema' => {'n' => {'type' => 'array'}}}, ['-n', 'abc'])['n'].should == ['abc']
      end
    end

    context "positional arguments" do
      let(:schema) do
        {'schema' => {'n' => {'position' => 1},
                      'o' => {'position' => 0}}}
      end
      it "fails without a command schema" do
        expect{extract(nil, ['123'])}.
            to raise_error(ArgumentError, 'Unexpected argument 123')
      end
      it "fails if no positional arguments exist for a command" do
        expect{extract({'schema' => {'n' => {}}}, ['abc'])}.
            to raise_error(ArgumentError, 'Unexpected argument abc')
      end
      it "succeeds if no position is supplied" do
        extract({'schema' => {'n' => {'position' => 0}}}, ['-n', '123'])['n'].
            should == '123'
      end
      it "succeeds if position exists and is supplied" do
        extract({'schema' => {'n' => {'position' => 0}}}, ['123'])['n'].
            should == '123'
      end
      it "succeeds if multiple positions exist and are supplied" do
        body = extract(schema, ['123', '456'])
        body['o'].should == '123'
        body['n'].should == '456'
      end
      it "fails if too many positions are supplied" do
        expect{extract(schema, ['123', '456', '789'])}.
            to raise_error(ArgumentError, 'Unexpected argument 789')
      end
      it "succeeds if multiple positions exist and one is supplied" do
        body = extract(schema, ['123'])
        body['o'].should == '123'
        body['n'].should == nil
      end
      it "succeeds with a combination of positional and flags" do
        body = extract(schema, ['123', '-n', '456'])
        body['o'].should == '123'
        body['n'].should == '456'
      end
      it "prefers the later between positional and flags" do
        body = extract(schema, ['123', '-o', '456'])
        body['o'].should == '456'
        body = extract(schema, ['-o', '456', '123'])
        body['o'].should == '123'
      end
      it "correctly sets datatypes" do
        schema =
            {'schema' => {'n' => {'type' => 'array', 'position' => 0},
                          'o' => {'type' => 'number', 'position' => 1},
                          'w' => {'type' => 'boolean', 'position' => 2},
                          'a' => {'type' => 'object', 'position' => 3},
                          'i' => {'type' => 'object', 'position' => 4}}}
        body = extract(schema, ['arr', '123', 'true', '{}', 'abc=123'])
        body['n'].should == ['arr']
        body['o'].should == 123
        body['w'].should == true
        body['a'].should == {}
        body['i'].should == {'abc' => '123'}
      end
    end
  end
end