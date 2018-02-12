require 'minitest/autorun'

require 'google/protobuf'
require_relative '../lib/twirp'

# Define the proto messages (this what the protoc generator would produce)
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "foopkg.DoFooRequest" do
    optional :foo, :string, 1
  end
  add_message "foopkg.DoFooResponse" do
    optional :bar, :string, 1
  end
end
module FooPkg
  DoFooRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("foopkg.DoFooRequest").msgclass
  DoFooResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("foopkg.DoFooResponse").msgclass
end

module FooPkg
  class FooService < Twirp::Service
    rpc "DoFoo", DoFooRequest, DoFooResponse, handler_method: :do_foo
  end
end

class FooHandler
  def do_foo(req)
    {bar: "Hello #{req.foo}"}
  end
end

class ServiceTest < Minitest::Test

  def test_rpc_methods
    assert_equal 1, FooPkg::FooService.rpcs.size
    assert_equal({
      request_class: FooPkg::DoFooRequest,
      response_class: FooPkg::DoFooResponse,
      handler_method: :do_foo,
    }, FooPkg::FooService.rpcs["DoFoo"])
  end
  
  def test_initialize_service
    svc = FooPkg::FooService.new(FooHandler.new)
    assert svc.respond_to?(:call)
  end

  # TODO test invalid configurations
  # TODO test fake HTTP requests, check responses ...
end
