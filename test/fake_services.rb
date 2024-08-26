# Fake messages, services and hadndlers for tests.

require 'google/protobuf'
require_relative '../lib/twirp'

# Protobuf messages.
# An example of the result of the protoc ruby code generator.
descriptor_data = "\n\ntest.proto\x12\x07\x65xample\"\x16\n\x04Size\x12\x0e\n\x06inches\x18\x01 \x01(\x05\"$\n\x03Hat\x12\x0e\n\x06inches\x18\x01 \x01(\x05\x12\r\n\x05\x63olor\x18\x02 \x01(\t\"\x07\n\x05\x45mptyb\x06proto3"
Google::Protobuf::DescriptorPool.generated_pool.add_serialized_file(descriptor_data)

module Example
  Size = Google::Protobuf::DescriptorPool.generated_pool.lookup("example.Size").msgclass
  Hat = Google::Protobuf::DescriptorPool.generated_pool.lookup("example.Hat").msgclass
  Empty = Google::Protobuf::DescriptorPool.generated_pool.lookup("example.Empty").msgclass
end

# Twirp Service.
# An example of the result of the protoc twirp_ruby plugin code generator.
module Example
  class Haberdasher < Twirp::Service
    package "example"
    service "Haberdasher"
    rpc :MakeHat, Size, Hat, :ruby_method => :make_hat
  end

  class HaberdasherClient < Twirp::Client
    client_for Haberdasher
  end
end

# Example service handler.
# It would be provided by the developer as implementation for the service.
class HaberdasherHandler
  def initialize(&block)
    @block = block if block_given?
  end

  def make_hat(input, env)
    @block && @block.call(input, env)
  end
end

# Twirp Service with no package and no rpc methods.
class EmptyService < Twirp::Service
end
class EmptyClient < Twirp::Client
end

# Foo message
descriptor_data = "\n\tfoo.proto\"\x12\n\x03\x46oo\x12\x0b\n\x03\x66oo\x18\x01 \x01(\tb\x06proto3"
Google::Protobuf::DescriptorPool.generated_pool.add_serialized_file(descriptor_data)

Foo = Google::Protobuf::DescriptorPool.generated_pool.lookup("Foo").msgclass

# Foo Client
class FooClient < Twirp::Client
  service "Foo"
  rpc :Foo, Foo, Foo, :ruby_method => :foo
end
