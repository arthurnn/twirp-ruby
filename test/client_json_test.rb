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
      assert_equal '{"blah1":1,"blah2":2}', req.body # body is json

      [200, {}, '{"blah_resp": 3}']
    }, package: "my.pkg", service: "Talking")

    resp = c.rpc :Blah, blah1: 1, blah2: 2
    assert_nil resp.error
    refute_nil resp.data
    assert_equal 3, resp.data["blah_resp"]
  end

  def test_client_json_thennable
    c = Twirp::ClientJSON.new(conn_stub_thennable("/my.pkg.Talking/Blah") {|req|
      assert_equal "application/json", req.request_headers['Content-Type']
      assert_equal '{"blah1":1,"blah2":2}', req.body # body is json

      [200, {}, '{"blah_resp": 3}']
    }, package: "my.pkg", service: "Talking")

    resp_thennable = c.rpc :Blah, blah1: 1, blah2: 2
    # the final `.then {}` call will yield a ClientResp
    assert resp_thennable.is_a?(Thennable)
    resp = resp_thennable.value
    assert resp.is_a?(Twirp::ClientResp)

    # the final Thennable will have come from one with a faraday response
    assert resp_thennable.parent.is_a?(Thennable)
    assert resp_thennable.parent.value.is_a?(Faraday::Response)

    # the final ClientResp should look the same as when then isn't used
    assert_nil resp.error
    refute_nil resp.data
    assert_equal 3, resp.data["blah_resp"]
  end

  def test_client_json_strict_encoding
    c = Twirp::ClientJSON.new(conn_stub("/my.pkg.Talking/Blah") {|req|
      assert_equal "application/json; strict=true", req.request_headers['Content-Type']
      assert_equal '{"blah1":1,"blah2":2}', req.body # body is json

      [200, {}, '{"blah_resp": 3}']
    }, package: "my.pkg", service: "Talking", strict: true)

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

  # mock of a promise-like thennable, allowing a call to ".then" to get the real value
  class Thennable
    attr_reader :value, :parent

    def initialize(value, parent = nil)
      @value = value
      @parent = parent
    end

    def then(&block)
      # similar to a promise, but runs immediately
      Thennable.new(block.call(@value), self)
    end
  end

  module ThennableFaraday
    def post(*)
      Thennable.new(super)
    end
  end

  def conn_stub_thennable(path, &block)
    s = conn_stub(path, &block)
    s.extend(ThennableFaraday)
    s
  end

 end
