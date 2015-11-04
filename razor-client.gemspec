# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "razor-client"
  spec.version       = "1.1.0"
  spec.authors       = ["Puppet Labs"]
  spec.email         = ["info@puppetlabs.com"]
  spec.description   = "The client for the Razor server"
  spec.summary       = "The client for everybody's favorite provisioning tool"
  spec.homepage      = "https://github.com/puppetlabs/razor-client"
  spec.license       = "ASL2"

  spec.files         = `git ls-files`.split($/)
  spec.bindir        = "bin"
  spec.executables   = ['razor']
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  # This is added until compatibility issues can be resolved in
  # e.g. https://tickets.puppetlabs.com/browse/RAZOR-572. This is only
  # effective for locally built gems, as project_data.yaml does not support
  # this feature.
  spec.required_ruby_version = '>= 1.9.2'

  # mime-types is a dependency of rest-client. We need to explicitly depend
  # on it and pin its version to make sure the gem works with Ruby 1.8.7
  spec.add_dependency "mime-types", '< 2.0'
  spec.add_dependency "multi_json"
  # `rest-client` adds an undesirable dependency on Ruby >= 1.9.2 in version 1.7.0.
  spec.add_dependency "rest-client", '< 1.7'
  spec.add_dependency "command_line_reporter", '~> 3.0'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
