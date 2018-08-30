source 'https://rubygems.org'

raise 'Ruby should be >2.0' unless RUBY_VERSION.to_f > 2.0

def location_for(place, fake_version = nil)
  if place =~ /^(git[:@][^#]*)#(.*)/
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

gem 'rest-client', '> 2.0.0'
gem 'command_line_reporter', '>=3.0'
gem 'gettext-setup'
gem 'rack', '< 2.0.0', '>= 1.5.4'
gem 'multi_json'
gem 'domain_name', '>= 0.5.20180417'
gem 'unf', '>= 0.2.0.beta2'

group :packaging do
  gem 'packaging', *location_for(ENV['PACKAGING_LOCATION'] || '~> 0.99')
end

group :doc do
  gem 'yard'
  gem 'kramdown'
end

# This group will be excluded by default in `torquebox archive`
group :test do
  gem 'public_suffix', '~> 1.4.6'
  gem 'rack-test'
  gem 'rspec', '~> 2.13.0'
  gem 'rspec-core', '~> 2.13.1'
  gem 'rspec-expectations', '~> 2.13.0'
  gem 'rspec-mocks', '~> 2.13.1'
  gem 'simplecov'
  gem 'webmock', '~> 3.3.0'
  gem 'vcr', '~> 4.0.0'
end

group :development do
  gem 'rake'
end

# This allows you to create `Gemfile.local` and have it loaded automatically;
# the purpose of this is to allow you to put additional development gems
# somewhere convenient without having to constantly mess with this file.
#
# Gemfile.local is in the .gitignore file; do not check one in!
eval(File.read(File.dirname(__FILE__) + '/Gemfile.local'), binding) rescue nil
