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
def reset_db
  razor_admin_path = ENV['razor-admin'] || 'bin/razor-admin'
  db_environment = ENV['server-database-environment'] || 'development'
  # The `cd` business is a workaround, since running `razor-admin` from a
  # different directory currently fails. Without the `Bundler` wrap, it uses
  # the same bundler environment for the shell command, leading to errors
  # relating to gems on razor-server that are not included in the razor-client
  # bundle.
  Bundler.with_clean_env {system("cd ../razor-server && #{razor_admin_path} -e #{db_environment} reset-database")}
end

# Record one cassette for each test
RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.before(:each) do
    ENV::store('RAZOR_API', 'http://localhost:8150/api')
  end
  # Make tests have no side effects when [re-]recording.
  if vcr_recording?
    c.before(:all) { reset_db }
    c.after(:each, :vcr => true) { reset_db }
  end
end