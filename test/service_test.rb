require 'minitest/autorun'
require 'rack/mock'

require 'google/protobuf'
require_relative '../lib/twirp'

# Protobuf messages.
# This is what the protoc code generator would produce.
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

# Twirp Service.
# This is wha the twirp_ruby protoc plugin code generator would produce.
module FooPkg
  class FooService < Twirp::Service
    package "foopkg"
    service "FooService"

    rpc "DoFoo", DoFooRequest, DoFooResponse, handler_method: :do_foo
  end
end

# Example service handler.
# This would be provided by the developer as implementation for the service.
class FooHandler
  def do_foo(req)
    {bar: "Hello #{req.foo}"}
  end
end

# Twirp Service with no package and no rpc methods.
class EmptyService < Twirp::Service
end

class ServiceTest < Minitest::Test

  def test_rpc_methods
    # make sure that rpcs have been properly setup by the `rpc` DSL constructor
    assert_equal 1, FooPkg::FooService.rpcs.size
    assert_equal({
      request_class: FooPkg::DoFooRequest,
      response_class: FooPkg::DoFooResponse,
      handler_method: :do_foo,
    }, FooPkg::FooService.rpcs["DoFoo"])
  end

  def test_package_service_getters
    assert_equal "foopkg", FooPkg::FooService.package_name
    assert_equal "FooService", FooPkg::FooService.service_name
    assert_equal "foopkg.FooService", FooPkg::FooService.path_prefix

    assert_equal "", EmptyService.package_name # defaults to empty string
    assert_equal "EmptyService", EmptyService.service_name # defaults to class name
    assert_equal "EmptyService", EmptyService.path_prefix # with no package is just the service name
  end
  
  def test_initialize_service
    # simple initialization
    svc = FooPkg::FooService.new(FooHandler.new)
    assert svc.respond_to?(:call) # so it is a Proc that can be used as Rack middleware

    empty_svc = EmptyService.new(nil) # an empty service does not need a handler
    assert svc.respond_to?(:call)
  end

  def test_path_prefix
    svc = FooPkg::FooService.new(FooHandler.new)
    assert_equal "foopkg.FooService", svc.path_prefix
  end

  def test_initialize_fails_on_invalid_handlers
    assert_raises ArgumentError do 
      FooPkg::FooService.new() # handler is mandatory
    end

    # verify that handler implements required methods
    err = assert_raises ArgumentError do 
      FooPkg::FooService.new("fake handler")
    end
    assert_equal "Handler must respond to .do_foo(req) in order to handle the message DoFoo.", err.message
  end

  def test_successful_simple_request
    env = Rack::MockRequest.env_for("/twirp/foopkg.FooService/DoFoo", method: "POST", 
      input: '{"foo": "World"}', "CONTENT_TYPE" => "application/json")

    svc = FooPkg::FooService.new(FooHandler.new)
    status, headers, body = svc.call(env)

    assert_equal 200, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal body[0], '{"bar":"Hello World"}'
  end

end
