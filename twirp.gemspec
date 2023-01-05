# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'twirp/version'

Gem::Specification.new do |spec|
  spec.name          = "twirp"
  spec.version       = Twirp::VERSION
  spec.authors       = ["Cyrus A. Forbes", "Mario Izquierdo"]
  spec.email         = ["forbescyrus@gmail.com", "tothemario@gmail.com"]
  spec.summary       = %q{Twirp services in Ruby.}
  spec.description   = %q{Twirp is a simple RPC framework with protobuf service definitions. The Twirp gem provides native support for Ruby.}
  spec.homepage      = "https://github.com/github/twirp-ruby"
  spec.license       = "MIT"

  spec.files         = Dir['lib/**/*'] + %w(Gemfile LICENSE README.md twirp.gemspec)
  spec.test_files    = Dir['test/**/*']
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9'
  spec.add_runtime_dependency 'google-protobuf', '~> 3.0', '>= 3.7.0'
  spec.add_runtime_dependency 'faraday', '< 3' # for clients

  spec.add_development_dependency 'bundler', '~> 2'
  spec.add_development_dependency 'minitest', '>= 5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rack', '>= 2.2.3'
end
