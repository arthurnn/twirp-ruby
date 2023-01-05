# Fake messages, services and hadndlers for tests.

require 'google/protobuf'
require_relative '../lib/twirp'

# Protobuf messages.
# An example of the result of the protoc ruby code generator.
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "example.Size" do
    optional :inches, :int32, 1
  end
  add_message "example.Hat" do
    optional :inches, :int32, 1
    optional :color, :string, 2
  end
  add_message "example.Empty" do
  end
end

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
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "Foo" do
    optional :foo, :string, 1
  end
end
Foo = Google::Protobuf::DescriptorPool.generated_pool.lookup("Foo").msgclass

# Foo Client
class FooClient < Twirp::Client
  service "Foo"
  rpc :Foo, Foo, Foo, :ruby_method => :foo
end
