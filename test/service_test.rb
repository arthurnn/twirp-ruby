require 'minitest/autorun'
require 'rack/mock'
require 'google/protobuf'
require 'json'

require_relative '../lib/twirp'
require_relative './fake_services'

class ServiceTest < Minitest::Test

  # The rpc DSL should properly build the base Twirp environment for each rpc method.
  def test_base_envs_accessor
    assert_equal 1, Example::Haberdasher.base_envs.size
    assert_equal({
      rpc_method: :MakeHat,
      input_class: Example::Size,
      output_class: Example::Hat,
      handler_method: :make_hat,
    }, Example::Haberdasher.base_envs["MakeHat"])
  end

  # DSL package and service define the proper data on the service
  def test_package_service_getters
    assert_equal "example", Example::Haberdasher.package_name
    assert_equal "Haberdasher", Example::Haberdasher.service_name
    assert_equal "example.Haberdasher", Example::Haberdasher.service_full_name

    assert_equal "", EmptyService.package_name # defaults to empty string
    assert_equal "EmptyService", EmptyService.service_name # defaults to class name
    assert_equal "EmptyService", EmptyService.service_full_name # with no package is just the service name
  end
  
  def test_init_service
    svc = Example::Haberdasher.new(HaberdasherHandler.new)
    assert svc.respond_to?(:call) # so it is a Proc that can be used as Rack middleware
    assert_equal "example.Haberdasher", svc.full_name
  end

  def test_init_empty_service
    empty_svc = EmptyService.new(nil) # an empty service does not need a handler
    assert empty_svc.respond_to?(:call)
    assert_equal "EmptyService", empty_svc.full_name
  end

  def test_successful_json_request
    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 200, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({"inches" => 10, "color" => "white"}, JSON.parse(body[0]))
  end

  def test_successful_proto_request
    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new(inches: 10)
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 200, status
    assert_equal 'application/protobuf', headers['Content-Type']
    assert_equal Example::Hat.new(inches: 10, color: "white"), Example::Hat.decode(body[0])
  end

  def test_bad_route_with_wrong_rpc_method
    rack_env = json_req "/twirp/example.Haberdasher/MakeUnicorns", and_rainbows: true
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg"  => 'Invalid rpc method "MakeUnicorns"',
      "meta" => {"twirp_invalid_route" => "POST /twirp/example.Haberdasher/MakeUnicorns"},
    }, JSON.parse(body[0]))    
  end

  def test_bad_route_with_wrong_http_method
    rack_env = Rack::MockRequest.env_for "example.Haberdasher/MakeHat", 
      method: "GET", input: '{"inches": 10}', "CONTENT_TYPE" => "application/json"
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg"  => 'HTTP request method must be POST',
      "meta" => {"twirp_invalid_route" => "GET /example.Haberdasher/MakeHat"},
    }, JSON.parse(body[0]))
  end

  def test_bad_route_with_wrong_content_type
    rack_env = Rack::MockRequest.env_for "example.Haberdasher/MakeHat", 
      method: "POST", input: 'free text', "CONTENT_TYPE" => "text/plain"
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg"  => 'unexpected Content-Type: "text/plain". Content-Type header must be one of application/json or application/protobuf',
      "meta" => {"twirp_invalid_route" => "POST /example.Haberdasher/MakeHat"},
    }, JSON.parse(body[0]))
  end

  def test_bad_route_with_wrong_path_json
    rack_env = json_req "/wrongpath", {}
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg"  => 'Invalid route. Expected format: POST {BaseURL}/example.Haberdasher/{Method}',
      "meta" => {"twirp_invalid_route" => "POST /wrongpath"},
    }, JSON.parse(body[0]))
  end

  def test_bad_route_with_wrong_path_protobuf
    rack_env = proto_req "/another/wrong.Path/MakeHat", Example::Empty.new()
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type'] # error responses are always JSON, even for Protobuf requests
    assert_equal({
      "code" => 'bad_route', 
      "msg"  => 'Invalid route. Expected format: POST {BaseURL}/example.Haberdasher/{Method}',
      "meta" => {"twirp_invalid_route" => "POST /another/wrong.Path/MakeHat"},
    }, JSON.parse(body[0]))
  end

  def test_bad_route_with_wrong_json_body
    rack_env = Rack::MockRequest.env_for "example.Haberdasher/MakeHat", 
      method: "POST", input: 'bad json', "CONTENT_TYPE" => "application/json"
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg"  => 'Invalid request body for rpc method "MakeHat" with Content-Type=application/json',
      "meta" => {"twirp_invalid_route" => "POST /example.Haberdasher/MakeHat"},
    }, JSON.parse(body[0]))
  end

  def test_bad_route_with_wrong_protobuf_body
    rack_env = Rack::MockRequest.env_for "example.Haberdasher/MakeHat", 
      method: "POST", input: 'bad protobuf', "CONTENT_TYPE" => "application/protobuf"
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 404, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'bad_route', 
      "msg"  => 'Invalid request body for rpc method "MakeHat" with Content-Type=application/protobuf',
      "meta" => {"twirp_invalid_route" => "POST /example.Haberdasher/MakeHat"},
    }, JSON.parse(body[0]))
  end

  def test_long_base_url
    rack_env = json_req "long-ass/base/url/twirp/example.Haberdasher/MakeHat", {inches: 10}
    status, headers, body = haberdasher_service.call(rack_env)

    assert_equal 200, status
  end

  # Handler should be able to return an instance of the proto message
  def test_handler_returns_a_proto_message
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      Example::Hat.new(inches: 11)
    end)

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(rack_env)

    assert_equal 200, status
    assert_equal Example::Hat.new(inches: 11, color: ""), Example::Hat.decode(body[0])
  end

  # Handler should be able to return a hash with attributes
  def test_handler_returns_hash_attributes
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      {inches: 11}
    end)

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(rack_env)

    assert_equal 200, status
    assert_equal Example::Hat.new(inches: 11, color: ""), Example::Hat.decode(body[0])
  end

  # Handler should be able to return Twirp::Error values, that will trigger error responses
  def test_handler_returns_twirp_error
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      return Twirp::Error.invalid_argument "I don't like that size"
    end)

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new(inches: 666)
    status, headers, body = svc.call(rack_env)
    assert_equal 400, status
    assert_equal 'application/json', headers['Content-Type'] # error responses are always JSON, even for Protobuf requests
    assert_equal({
      "code" => 'invalid_argument', 
      "msg" => "I don't like that size",
    }, JSON.parse(body[0]))
  end

  # Handler should be able to raise a Twirp::Exception, that will trigger error responses
  def test_handler_raises_twirp_exception
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      raise Twirp::Exception.new(:invalid_argument, "I don't like that size")
    end)

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new(inches: 666)
    status, headers, body = svc.call(rack_env)
    assert_equal 400, status
    assert_equal 'application/json', headers['Content-Type'] # error responses are always JSON, even for Protobuf requests
    assert_equal({
      "code" => 'invalid_argument', 
      "msg" => "I don't like that size",
    }, JSON.parse(body[0]))
  end

  def test_handler_method_can_set_response_headers_through_the_env
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      env[:http_response_headers]["Cache-Control"] = "public, max-age=60"
      {}
    end)

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(rack_env)
    
    assert_equal 200, status
    assert_equal "public, max-age=60", headers["Cache-Control"] # set by the handler
    assert_equal "application/protobuf", headers["Content-Type"] # set by Twirp::Service
  end

  def test_handler_returns_invalid_type_nil
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      nil
    end)

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(rack_env)

    assert_equal 500, status
    assert_equal({
      "code" => 'internal',
      "msg" => "Handler method make_hat expected to return one of Example::Hat, Hash or Twirp::Error, but returned NilClass.",
    }, JSON.parse(body[0]))
  end

  def test_handler_returns_invalid_type_string
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      "bad type"
    end)

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(rack_env)

    assert_equal 500, status
    assert_equal({
      "code" => 'internal',
      "msg" => "Handler method make_hat expected to return one of Example::Hat, Hash or Twirp::Error, but returned String.",
    }, JSON.parse(body[0]))
  end

  def test_handler_not_implementing_method
    svc = Example::Haberdasher.new("foo")

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new
    status, headers, body = svc.call(rack_env)

    assert_equal 501, status
    assert_equal({
      "code" => 'unimplemented',
      "msg" => "Handler does not respond to method make_hat.",
    }, JSON.parse(body[0]))
  end

  # TODO: test_handler_returns_invalid_attributes (ArgumentError should be handled)

  # TODO: test_handler_raises_standard_error

  def test_before_hook_simple
    handler_method_called = false
    handler = HaberdasherHandler.new do |size, env|
      handler_method_called = true
      {}
    end

    called_with_env = nil
    called_with_rack_env = nil
    svc = Example::Haberdasher.new(handler)
    svc.before do |env, rack_env|
      env[:raw_contet_type] = rack_env["CONTENT_TYPE"]
      called_with_env = env
      called_with_rack_env = rack_env
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    refute_nil called_with_env, "the before hook was called with a Twirp env"
    assert_equal :MakeHat, called_with_env[:rpc_method]
    assert_equal Example::Size.new(inches: 10), called_with_env[:input]
    assert_equal "application/json", called_with_env[:raw_contet_type]

    refute_nil called_with_rack_env, "the before hook was called with a Rack env"
    assert_equal "POST", called_with_rack_env["REQUEST_METHOD"]

    assert handler_method_called, "the handler method was called"
    assert_equal 200, status, "response is successful"
  end

  def test_before_hook_add_data_in_env_for_the_handler_method
    val = nil
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      val = env[:from_the_hook]
      {}
    end)
    svc.before do |env, rack_env|
      env[:from_the_hook] = "hello handler"
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 200, status
    assert_equal "hello handler", val
  end


  def test_before_hook_returning_twirp_error_cancels_request
    handler_called = false
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      handler_called = true
      {}
    end)
    svc.before do |env, rack_env|
      return Twirp::Error.internal "error from before hook"
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 500, status
    assert handler_called
    assert_equal({
      "code" => 'intenal', 
      "msg"  => 'error from before hook',
    }, JSON.parse(body[0]))
  end

  def test_multiple_before_hooks_executed_in_order
    handler_called = false
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      handler_called = true
      refute_nil env[:from_hook_1]
      refute_nil env[:from_hook_2]
      {}
    end)
    svc.before do |env, rack_env|
      assert_nil env[:from_hook_1]
      assert_nil env[:from_hook_2]
      env[:from_hook_1] = true
    end
    svc.before do |env, rack_env|
      refute_nil env[:from_hook_1]
      assert_nil env[:from_hook_2]
      env[:from_hook_2] = true
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 200, status
    assert_equal true, handler_called
  end

  def test_multiple_before_hooks_first_returning_error_halts_chain
    hook1_called = false
    hook2_called = false
    handler_called = false
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      handler_called = true
      {}
    end)
    svc.before do |env, rack_env|
      hook1_called = true
      return Twirp::Error.internal "hook1 failed"
    end
    svc.before do |env, rack_env|
      hook2_called = true
      return Twirp::Error.internal "hook2 failed"
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 500, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'intenal', 
      "msg"  => 'hook1 failed',
    }, JSON.parse(body[0]))

    assert hook1_called
    refute hook2_called
    refute handler_called
  end

  # TODO: test_before_hook_raising_exception_cancels_request

  def test_success_hook_simple
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |input, env|
      env[:handler_called] = true
      {inches: 88, color: "blue"}
    end)
    success_called = false
    svc.success do |env|
      success_called = true
      assert env[:handler_called]
      assert_equal Example::Hat.new(inches: 88, color: "blue"), env[:output] # output from hadnler
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 200, status
    assert success_called
  end

  def test_success_hook_does_not_trigger_on_error
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |input, env|
      return Twirp::Error.internal "error from handler"
    end)
    success_called = false
    svc.success do |env|
      success_called = true
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 500, status
    refute success_called # after hook not called
    assert_equal({
      "code" => 'intenal', 
      "msg"  => 'error from handler',
    }, JSON.parse(body[0]))
  end

  def test_success_hook_returning_twirp_error_overrides_response
    handler_called = false
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      handler_called = true
      {inches: 88, color: "blue"}
    end)
    svc.success do |env|
      return Twirp::Error.internal "error from after hook"
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 500, status
    assert handler_called
    assert_equal({
      "code" => 'intenal', 
      "msg"  => 'error from after hook',
    }, JSON.parse(body[0]))
  end

  def test_success_hook_returning_twirp_error_overrides_response_error
    handler_called = false
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      handler_called = true
      return Twirp::Error.invalid_argument "erro from handler"
    end)
    svc.success do |env|
      return Twirp::Error.internal "error from after hook"
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 500, status
    assert handler_called
    assert_equal({
      "code" => 'intenal', 
      "msg"  => 'error from after hook',
    }, JSON.parse(body[0]))
  end

  def test_multiple_success_hooks_executed_in_order
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      env[:from_handler] = true
      {}
    end)
    svc.success do |env|
      refute_nil env[:from_handler]
      assert_nil env[:from_hook_1]
      assert_nil env[:from_hook_2]
      env[:from_hook_1] = true
    end
    hook2_called = false
    svc.success do |env|
      refute_nil env[:from_handler]
      refute_nil env[:from_hook_1]
      assert_nil env[:from_hook_2]
      env[:from_hook_2] = true
      hook2_called = true
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 200, status
    assert hook2_called
  end

  def test_multiple_success_hooks_first_returning_error_halts_chain
    hook1_called = false
    hook2_called = false
    handler_called = false
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      handler_called = true
      {}
    end)
    svc.success do |env|
      hook1_called = true
      return Twirp::Error.internal "hook1 failed"
    end
    svc.success do |env|
      hook2_called = true
      return Twirp::Error.internal "hook2 failed"
    end

    rack_env = json_req "/example.Haberdasher/MakeHat", inches: 10
    status, _, _ = svc.call(rack_env)

    assert_equal 500, status
    assert_equal 'application/json', headers['Content-Type']
    assert_equal({
      "code" => 'intenal', 
      "msg"  => 'hook1 failed',
    }, JSON.parse(body[0]))

    assert hook1_called
    refute hook2_called
    refute handler_called
  end

  # TODO: test_success_hook_raising_exception_cancels_request



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
    Example::Haberdasher.new(HaberdasherHandler.new do |size, _|
      {inches: size.inches, color: "white"}
    end)
  end
end

