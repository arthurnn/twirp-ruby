require 'minitest/autorun'
require 'rack/mock'
require 'google/protobuf'
require 'json'

require_relative '../lib/twirp/client_json'
require_relative './fake_services'

class ClientJSONTest < Minitest::Test

  def test_client_json_requires_service
    assert_raises ArgumentError do
      Twirp::ClientJSON.new("http://localhost:8080") # missing service
    end
    Twirp::ClientJSON.new("http://localhost:8080", service: "FooBar") # ok
  end

  def test_client_json_success
    c = Twirp::ClientJSON.new(conn_stub("/my.pkg.Talking/Blah") {|req|
      assert_equal "application/json", req.request_headers['Content-Type']
      assert_equal "application/json", req.request_headers['Accept']
      assert_equal '{"blah1":1,"blah2":2}', req.body # body is json

      [200, {}, '{"blah_resp": 3}']
    }, package: "my.pkg", service: "Talking")

    resp = c.rpc :Blah, blah1: 1, blah2: 2
    assert_nil resp.error
    refute_nil resp.data
    assert_equal 3, resp.data["blah_resp"]
  end

  def test_client_json_error
    c = Twirp::ClientJSON.new(conn_stub("/Foo/Foomo") {|req|
      [400, {}, '{"code": "invalid_argument", "msg": "dont like empty"}']
    }, service: "Foo")

    resp = c.rpc :Foomo, foo: ""
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :invalid_argument, resp.error.code
    assert_equal "dont like empty", resp.error.msg
  end

  def test_client_bad_json_route
    c = Twirp::ClientJSON.new(conn_stub("/Foo/OtherMethod") {|req|
      [404, {}, 'not here buddy']
    }, service: "Foo")

    resp = c.rpc :OtherMethod, foo: ""
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :bad_route, resp.error.code
  end


  def conn_stub(path)
    Faraday.new do |conn|
      conn.adapter :test do |stub|
        stub.post(path) do |env|
          yield(env)
        end
      end
    end
  end

 end
