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

  describe "extract_command" do
    it "should understand --arg=value"
    it "should understand '--arg value'"
  end
end
