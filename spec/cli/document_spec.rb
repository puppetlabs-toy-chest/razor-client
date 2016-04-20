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

describe Razor::CLI::Document do
  def document(doc, format_type)
    Razor::CLI::Document.new(doc, format_type)
  end
  def check_doc(reality, expectation)
    [:spec, :items, :type, :format_view, :command].each do |prop|
      reality.public_send(prop).should == expectation[prop] if expectation[prop]
    end
  end
  describe "#new" do
    it "creates a blank document successfully" do
      doc = document({}, 'short')
      check_doc(doc, items: [{}], type: :single)
    end
    it "creates a normal document successfully" do
      doc = document({'spec' => 'some/path', 'abc' => 'def'}, 'short')
      check_doc(doc, type: :single, spec: 'some/path')
    end
    it "includes the command if supplied" do
      doc = document({'spec' => 'some/path', 'abc' => 'def', 'command' => 123}, 'short')
      check_doc(doc, type: :single, spec: 'some/path', command: 123)
    end
    it "finds formatting based on the spec string" do
      Razor::CLI::Views.views = {'collections' => {'item' => {'+short' => {'+layout' => 'list'}}}}
      doc = document({'spec' => '/collections/item', 'abc' => 'def'}, 'short')
      check_doc(doc, type: :single, spec: '/collections/item', format_view: {'+layout' => 'list'})
    end
    it "finds formatting based on the spec array" do
      Razor::CLI::Views.views = {'collections' => {'more' => {'scoping' => {'+short' => {'+layout' => 'list'}}}}}
      doc = document({'+spec' => ['/collections/more', 'scoping'], 'abc' => 'def'}, 'short')
      check_doc(doc, type: :single, spec: '/collections/more', format_view: {'+layout' => 'list'})
    end
  end
end
