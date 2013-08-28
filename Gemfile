source 'https://rubygems.org'

gem 'rest-client'
gem 'terminal-table'

group :doc do
  gem 'yard'
  gem 'kramdown'
end

# This group will be excluded by default in `torquebox archive`
group :test do
  gem 'rack-test'
  gem 'rspec', '~> 2.13.0'
  gem 'rspec-core', '~> 2.13.1'
  gem 'rspec-expectations', '~> 2.13.0'
  gem 'rspec-mocks', '~> 2.13.1'
  gem 'simplecov'
  gem 'webmock'
  gem 'vcr'
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
