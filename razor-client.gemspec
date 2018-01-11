# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "razor-client"
  spec.version       = `git describe --tags`.tr('-', '.').chomp
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
  spec.required_ruby_version = '>= 2.0.0'

  spec.add_dependency "mime-types"
  spec.add_dependency "multi_json"
  # `rest-client` has a security vulnerability prior to this version.
  spec.add_dependency "rest-client", '~> 2.0'
  spec.add_dependency "command_line_reporter", '~> 3.0'
  spec.add_dependency "gettext-setup", '~> 0.29'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
