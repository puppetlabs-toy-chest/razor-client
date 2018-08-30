require 'rake'
require 'yaml'

# Needed to make the client work on Ruby 1.8.7
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'spec/vcr_library'

namespace :bundler do
  task :setup do
    require 'bundler/setup'
  end
end

if defined?(RSpec::Core::RakeTask)
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
end

desc "Erase all VCR recordings"
task :"vcr:erase" do
  erase_vcr_library
end

##############################################################################
# Support for our internal packaging toolchain.  Most people outside of Puppet
# Labs will never actually need to deal with these.
begin
  require 'packaging'
  Pkg::Util::RakeUtils.load_packaging_tasks
rescue LoadError => e
  puts "Error loading packaging rake tasks: #{e}"
end

# Kept for backwards compatibility
namespace :package do
  desc "Bootstrap packaging automation, e.g. clone into packaging repo"
  task :bootstrap do
    puts 'Bootstrap is no longer needed, using packaging-as-a-gem'
  end

  desc "Remove all cloned packaging automation"
  task :implode do
    puts 'Implode is no longer needed, using packaging-as-a-gem'
  end
end

begin
  spec = Gem::Specification.find_by_name 'gettext-setup'
  load "#{spec.gem_dir}/lib/tasks/gettext.rake"
  GettextSetup.initialize(File.absolute_path('locales', File.dirname(__FILE__)))
rescue LoadError
end
