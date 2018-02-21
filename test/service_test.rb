require 'minitest/autorun'
require 'rack/mock'
require 'google/protobuf'
require 'json'

require_relative '../lib/twirp'
require_relative './fake_services'

class ServiceTest < Minitest::Test

  # DSL rpc builds the proper rpc data on the service
  def test_rpc_methods
    assert_equal 1, Example::Haberdasher.rpcs.size
    assert_equal({
      request_class: Example::Size,
      response_class: Example::Hat,
      handler_method: :make_hat,
    }, Example::Haberdasher.rpcs["MakeHat"])
  end

  # DSL package and service define the proper data on the service
  def test_package_service_getters
    assert_equal "example", Example::Haberdasher.package_name
    assert_equal "Haberdasher", Example::Haberdasher.service_name
    assert_equal "example.Haberdasher", Example::Haberdasher.path_prefix

    assert_equal "", EmptyService.package_name # defaults to empty string
    assert_equal "EmptyService", EmptyService.service_name # defaults to class name
    assert_equal "EmptyService", EmptyService.path_prefix # with no package is just the service name
  end
  
  # Simple check for initialization
  def test_initialize_service
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

  def test_successful_json_request
    env = json_req "/twirp/example.Haberdasher/MakeHat", inches: 10

    svc = Example::Haberdasher.new(HaberdasherHandler.new)
    status, headers, body = svc.call(env)
    resp = JSON.parse(body[0])

    assert_equal 200, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({"inches" => 10, "color" => "white"}, resp)
  end

  def test_successful_proto_request
    env = proto_req "/twirp/example.Haberdasher/MakeHat", Example::Size.new(inches: 10)

    svc = Example::Haberdasher.new(HaberdasherHandler.new)
    status, headers, body = svc.call(env)
    resp = Example::Hat.decode(body[0])

    assert_equal 200, status
    assert_equal 'application/protobuf', headers['Content-Type']
    assert_equal Example::Hat.new(inches: 10, color: "white"), resp
  end



  # Test Helpers
  # ------------

  def json_req(path, attrs)
    Rack::MockRequest.env_for(path, 
      method: "POST", 
      input: JSON.generate(attrs),
      "CONTENT_TYPE" => "application/json")
  end

  def proto_req(path, proto_message)
    Rack::MockRequest.env_for(path, 
      method: "POST", 
      input: proto_message.class.encode(proto_message),
      "CONTENT_TYPE" => "application/protobuf")
  end
end

