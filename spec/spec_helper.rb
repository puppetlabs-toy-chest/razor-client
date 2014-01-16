require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require 'multi_json'
require 'vcr'

require_relative '../lib/razor'
require_relative 'vcr_library'

def vcr_record_mode
  (ENV['VCR_RECORD'] || :none).to_sym
end

def vcr_recording?
  vcr_record_mode != :none
end

VCR.configure do |c|
  # NOTE: Empty this directory before re-recording
  c.cassette_library_dir = VCR_LIBRARY
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.default_cassette_options = {
    :record => vcr_record_mode
  }
end

# Record one cassette for each test
RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.before(:each) do
    ENV::delete('RAZOR_API')
  end
end
