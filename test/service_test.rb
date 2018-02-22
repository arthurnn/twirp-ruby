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
      rpc_method: "MakeHat",
      input_class: Example::Size,
      output_class: Example::Hat,
      handler_method: "make_hat",
    }, Example::Haberdasher.rpcs["MakeHat"])
  end

  # DSL package and service define the proper data on the service
  def test_package_service_getters
    assert_equal "example", Example::Haberdasher.package_name
    assert_equal "Haberdasher", Example::Haberdasher.service_name
    assert_equal "example.Haberdasher", Example::Haberdasher.service_full_name
    assert_equal "/twirp/example.Haberdasher", Example::Haberdasher.path_prefix

    assert_equal "", EmptyService.package_name # defaults to empty string
    assert_equal "EmptyService", EmptyService.service_name # defaults to class name
    assert_equal "EmptyService", EmptyService.service_full_name # with no package is just the service name
    assert_equal "/twirp/EmptyService", EmptyService.path_prefix
  end
  
  def test_init_service
    svc = Example::Haberdasher.new(HaberdasherHandler.new)
    assert svc.respond_to?(:call) # so it is a Proc that can be used as Rack middleware
    assert_equal "example.Haberdasher", svc.service_full_name
    assert_equal "/twirp/example.Haberdasher", svc.path_prefix
  end

  def test_init_empty_service
    empty_svc = EmptyService.new(nil) # an empty service does not need a handler
    assert empty_svc.respond_to?(:call)
    assert_equal "EmptyService", empty_svc.service_full_name
    assert_equal "/twirp/EmptyService", empty_svc.path_prefix
  end

  def test_init_failures
    assert_raises ArgumentError do 
      Example::Haberdasher.new() # handler is mandatory
    end

    err = assert_raises ArgumentError do 
      Example::Haberdasher.new("fake handler")
    end
    assert_equal "Handler must respond to .make_hat(input) in order to handle the message MakeHat.", err.message
  end

  def test_successful_json_request
    env = json_req "/twirp/example.Haberdasher/MakeHat", inches: 10
    status, headers, body = haberdasher_service.call(env)

    assert_equal 200, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({"inches" => 10, "color" => "white"}, JSON.parse(body[0]))
  end

  def test_successful_proto_request
    env = proto_req "/twirp/example.Haberdasher/MakeHat", Example::Size.new(inches: 10)
    status, headers, body = haberdasher_service.call(env)

    assert_equal 200, status
    assert_equal 'application/protobuf', headers['Content-Type']
    assert_equal Example::Hat.new(inches: 10, color: "white"), Example::Hat.decode(body[0])
  end

  def test_bad_route_with_wrong_rpc_method
    env = json_req "/twirp/example.Haberdasher/MakeUnicorns", and_rainbows: true
    status, headers, body = haberdasher_service.call(env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg" => 'rpc method not found: "MakeUnicorns"',
      "meta"=> {"twirp_invalid_route" => "POST /twirp/example.Haberdasher/MakeUnicorns"},
    }, JSON.parse(body[0]))    
  end

  def test_bad_route_with_wrong_http_method
    env = Rack::MockRequest.env_for "/twirp/example.Haberdasher/MakeHat", 
      method: "GET", input: '{"inches": 10}', "CONTENT_TYPE" => "application/json"
    status, headers, body = haberdasher_service.call(env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg" => 'HTTP request method must be POST',
      "meta"=> {"twirp_invalid_route" => "GET /twirp/example.Haberdasher/MakeHat"},
    }, JSON.parse(body[0]))
  end

  def test_bad_route_with_wrong_content_type
    env = Rack::MockRequest.env_for "/twirp/example.Haberdasher/MakeHat", 
      method: "POST", input: 'free text', "CONTENT_TYPE" => "text/plain"
    status, headers, body = haberdasher_service.call(env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg" => 'unexpected Content-Type: "text/plain". Content-Type header must be one of "application/json" or "application/protobuf"',
      "meta"=> {"twirp_invalid_route" => "POST /twirp/example.Haberdasher/MakeHat"},
    }, JSON.parse(body[0]))
  end

  def test_bad_route_with_wrong_path_json
    env = json_req "/wrongpath", {}
    status, headers, body = haberdasher_service.call(env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg" => 'Invalid route. Expected format: POST {BaseURL}/twirp/(package.)?{Service}/{Method}',
      "meta"=> {"twirp_invalid_route" => "POST /wrongpath"},
    }, JSON.parse(body[0]))
  end

  def test_bad_route_with_wrong_path_protobuf
    env = proto_req "/another/wrong.Path/MakeHat", Example::Empty.new()
    status, headers, body = haberdasher_service.call(env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type'] # error responses are always JSON, even for Protobuf requests
    assert_equal({
      "code" => 'bad_route', 
      "msg" => 'Invalid route. Expected format: POST {BaseURL}/twirp/(package.)?{Service}/{Method}',
      "meta"=> {"twirp_invalid_route" => "POST /another/wrong.Path/MakeHat"},
    }, JSON.parse(body[0]))
  end

  # Handler should be able to return an instance of the proto message
  def test_handler_returns_a_proto_message
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size|
      Example::Hat.new(inches: 11)
    end)

    env = proto_req "/twirp/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(env)

    assert_equal 200, status
    assert_equal Example::Hat.new(inches: 11, color: ""), Example::Hat.decode(body[0])
  end

  # Handler should be able to return a hash with attributes
  def test_handler_returns_hash_attributes
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size|
      {inches: 11}
    end)

    env = proto_req "/twirp/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(env)

    assert_equal 200, status
    assert_equal Example::Hat.new(inches: 11, color: ""), Example::Hat.decode(body[0])
  end

  # Handler should be able to return nil, as a message with all zero-values
  def test_handler_returns_nil
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size|
      nil
    end)

    env = proto_req "/twirp/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(env)

    assert_equal 200, status
    assert_equal Example::Hat.new(inches: 0, color: ""), Example::Hat.decode(body[0])
  end

  # Handler should be able to return Twirp::Error values, that will trigger error responses
  def test_handler_returns_twirp_error
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size|
      return Twirp.invalid_argument_error "I don't like that size"
    end)

    env = proto_req "/twirp/example.Haberdasher/MakeHat", Example::Size.new(inches: 666)
    status, headers, body = svc.call(env)
    assert_equal 400, status
    assert_equal 'application/json', headers['Content-Type'] # error responses are always JSON, even for Protobuf requests
    assert_equal({
      "code" => 'invalid_argument', 
      "msg" => "I don't like that size",
    }, JSON.parse(body[0]))
  end

  # Handler should be able to raise a Twirp::Exception, that will trigger error responses
  def test_handler_raises_twirp_exception
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size|
      raise Twirp::Exception.new(:invalid_argument, "I don't like that size")
    end)

    env = proto_req "/twirp/example.Haberdasher/MakeHat", Example::Size.new(inches: 666)
    status, headers, body = svc.call(env)
    assert_equal 400, status
    assert_equal 'application/json', headers['Content-Type'] # error responses are always JSON, even for Protobuf requests
    assert_equal({
      "code" => 'invalid_argument', 
      "msg" => "I don't like that size",
    }, JSON.parse(body[0]))
  end

  # TODO: Error handler
  # def test_handler_raises_standard_error
  #   svc = Example::Haberdasher.new(HaberdasherHandler.new do |size|
  #     raise "random error"
  #   end)
  # end

  def test_before_hook_simple
    handler_method_called = false
    handler = HaberdasherHandler.new do |size|
      handler_method_called = true
      nil
    end

    called_with = nil
    svc = Example::Haberdasher.new(handler)
    svc.before do |rpc_method, input, request|
      called_with = {rpc_method: rpc_method, input: input, request: request}
    end

    env = json_req "/twirp/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(env)

    refute_nil called_with, "the before hook was called"
    assert_equal "MakeHat", called_with[:rpc_method]
    assert_equal Example::Size.new(inches: 10), called_with[:input]
    assert_equal "application/json", called_with[:request].get_header('CONTENT_TYPE') # the request is accessible

    assert handler_method_called, "the handler method was called"
    assert_equal 200, status, "response is successful"
  end



  # Test Helpers
  # ------------

  def json_req(path, attrs)
    Rack::MockRequest.env_for path, method: "POST", 
      input: JSON.generate(attrs),
      "CONTENT_TYPE" => "application/json"
  end

  def proto_req(path, proto_message)
    Rack::MockRequest.env_for path, method: "POST", 
      input: proto_message.class.encode(proto_message),
      "CONTENT_TYPE" => "application/protobuf"
  end

  def haberdasher_service
    Example::Haberdasher.new(HaberdasherHandler.new do |size|
      {inches: size.inches, color: "white"}
    end)
  end
end

