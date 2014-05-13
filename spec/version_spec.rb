# -*- encoding: utf-8 -*-
require_relative 'spec_helper'

describe Razor::CLI::VERSION do
  it "should not include a newline" do
    described_class.should_not =~ /\n/
  end
end
