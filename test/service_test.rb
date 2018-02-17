require 'minitest/autorun'
require 'rack/mock'

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
    optional :name, :string, 3
  end
end

module Example
  Size = Google::Protobuf::DescriptorPool.generated_pool.lookup("example.Size").msgclass
  Hat = Google::Protobuf::DescriptorPool.generated_pool.lookup("example.Hat").msgclass
end

# Twirp Service.
# An example of the result of the protoc twirp_ruby plugin code generator.
module Example
  class Haberdasher < Twirp::Service
    package "example"
    service "Haberdasher"

    rpc "MakeHat", Size, Hat, handler_method: :make_hat
  end
end

# Example service handler.
# This would be provided by the developer as implementation for the service.
class HaberdasherHandler
  def make_hat(size)
    if size.inches < 0
      return Twirp::Error.new(:invalid_argument, "I can't make a hat that small!", argument: "inches")
    end
    {
      inches: size.inches,
      color: "white",
      name:  "derby",
    }
  end
end

# Twirp Service with no package and no rpc methods.
class EmptyService < Twirp::Service
end

class ServiceTest < Minitest::Test

  def test_rpc_methods
    # make sure that rpcs have been properly setup by the `rpc` DSL constructor
    assert_equal 1, Example::Haberdasher.rpcs.size
    assert_equal({
      request_class: Example::Size,
      response_class: Example::Hat,
      handler_method: :make_hat,
    }, Example::Haberdasher.rpcs["MakeHat"])
  end

  def test_package_service_getters
    assert_equal "example", Example::Haberdasher.package_name
    assert_equal "Haberdasher", Example::Haberdasher.service_name
    assert_equal "example.Haberdasher", Example::Haberdasher.path_prefix

    assert_equal "", EmptyService.package_name # defaults to empty string
    assert_equal "EmptyService", EmptyService.service_name # defaults to class name
    assert_equal "EmptyService", EmptyService.path_prefix # with no package is just the service name
  end
  
  def test_initialize_service
    # simple initialization
    svc = Example::Haberdasher.new(HaberdasherHandler.new)
    assert svc.respond_to?(:call) # so it is a Proc that can be used as Rack middleware

    empty_svc = EmptyService.new(nil) # an empty service does not need a handler
    assert svc.respond_to?(:call)
  end

  def test_path_prefix
    svc = Example::Haberdasher.new(HaberdasherHandler.new)
    assert_equal "example.Haberdasher", svc.path_prefix
  end

  def test_initialize_fails_on_invalid_handlers
    assert_raises ArgumentError do 
      Example::Haberdasher.new() # handler is mandatory
    end

    # verify that handler implements required methods
    err = assert_raises ArgumentError do 
      Example::Haberdasher.new("fake handler")
    end
    assert_equal "Handler must respond to .make_hat(req) in order to handle the message MakeHat.", err.message
  end

  def test_successful_simple_request
    env = Rack::MockRequest.env_for("/twirp/example.Haberdasher/MakeHat", method: "POST", 
      input: '{"inches": 10}', "CONTENT_TYPE" => "application/json")

    svc = Example::Haberdasher.new(HaberdasherHandler.new)
    status, headers, body = svc.call(env)

    assert_equal 200, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal body[0], '{"inches":10,"color":"white","name":"derby"}'
  end

end
