require 'minitest/autorun'
require 'rack/mock'
require 'google/protobuf'
require 'json'

require_relative '../lib/twirp'
require_relative './fake_services'

class ServiceLoggingTest < Minitest::Test

  def setup
    Example::Haberdasher.raise_exceptions = true # configure for testing to make debugging easier
  end

  # Class method to make a Rack response with a Twirp errpr
  def test_service_request_logging
    mock_logger = MiniTest::Mock.new
    mock_logger.expect(:nil?, false)
    rack_env = {:content_type=>"application/protobuf",
                :rpc_method=>:MakeHat,
                :input_class=>Example::Size,
                :output_class=>Example::Hat,
                :ruby_method=>:make_hat,
                input: Example::Size.new(inches: 10),
                :http_response_headers=>{}}
    mock_logger.expect(:log, true, [{
      at: "request.before",
      twirp_service: "Example::Haberdasher",
      twirp_method: "MakeHat",
      env: rack_env
    }])

    Twirp.logger = mock_logger

    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new(inches: 10)
    status, headers, body = haberdasher_service.call(rack_env)

    Twirp.logger = nil
    assert_equal 200, status
    assert_equal 'application/protobuf', headers['Content-Type']

    mock_logger.verify
  end

  def test_logs_500_errors
    svc = Example::Haberdasher.new(HaberdasherHandler.new do |size, env|
      1 / 0 # divided by 0
    end)
    Example::Haberdasher.raise_exceptions = false
    rack_env = proto_req "/example.Haberdasher/MakeHat", Example::Size.new(inches: 10)

    status, headers, body = svc.call(rack_env)

    assert_equal 500, status

  end

  def test_logs_404_errors
  end

  def test_logs_response_time_for_errors
  end

  def test_logs_successful_response
  end

  def test_logs_response_time_for_success
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

