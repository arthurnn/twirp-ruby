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
  spec.description   = %q{Twirp is a simple RPC framework with protobuf service definitions. The Twirp gem provides support for Ruby.}
  spec.homepage      = "https://github.com/cyrusaf/ruby-twirp"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'google-protobuf', '>= 3.0.0'

  spec.add_development_dependency 'bundler', '>= 1'
end
