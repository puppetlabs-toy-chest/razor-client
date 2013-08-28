require 'rake'
require_relative 'spec/vcr_library'

namespace :bundler do
  task :setup do
    require 'bundler/setup'
  end
end

namespace :spec do
  require 'rspec/core'
  require 'rspec/core/rake_task'

  desc <<EOS
Run all specs. Set VCR_RECORD to 'all' to rerecord and to 'new_episodes'
to record new tests. Tapes are in #{VCR_LIBRARY}
EOS
  RSpec::Core::RakeTask.new(:all => :"bundler:setup") do |t|
    t.pattern = 'spec/**/*_spec.rb'
  end
end

desc "Erase all VCR recordings"
task :"vcr:erase" do
  erase_vcr_library
end
