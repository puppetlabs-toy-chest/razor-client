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

describe Razor::CLI::Format do
  include described_class

  def format(doc, args = {})
    args = {:format => '+short', :args => ['something', 'else']}.merge(args)
    parse = double(args)
    format_document doc, parse
  end

  context 'additional details' do
    it "tells additional details for a hash" do
      doc = {'abc' => {'def' => 'ghi'}}
      result = format doc
      result.should =~ /Query additional details via: `razor something else \[abc\]`\z/
    end
    it "tells additional details for an array" do
      doc = {'abc' => ['def']}
      result = format doc
      result.should =~ /Query additional details via: `razor something else \[abc\]`\z/
    end
    it "tells multiple additional details" do
      doc = {'abc' => ['def'], 'ghi' => {'jkl' => 'mno'}}
      result = format doc
      result.should =~ /Query additional details via: `razor something else \[abc, ghi\]`\z/
    end
    it "tells no additional details for a string" do
      doc = {'abc' => 'def'}
      result = format doc
      result.should_not =~ /Query additional details/
    end
    it "hides array spec array from additional details" do
      doc = {'abc' => [], 'spec' => ['def', 'jkl']}
      result = format doc
      result.should =~ /Query additional details via: `razor something else \[abc\]`\z/
    end
    it "hides array +spec array from additional details" do
      doc = {'abc' => [], '+spec' => ['def', 'jkl']}
      result = format doc
      result.should =~ /Query additional details via: `razor something else \[abc\]`\z/
    end
    it "tells how to query by name" do
      doc = {'items' => [{'name' => 'entirely'}, {'name' => 'bar'} ]}
      result = format doc
      result.should =~ /Query an entry by including its name, e.g. `razor something else entirely`\z/
    end
  end
end