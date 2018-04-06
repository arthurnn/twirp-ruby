require 'minitest/autorun'
require 'rack/mock'
require 'google/protobuf'
require 'json'

require_relative '../lib/twirp'
require_relative './fake_services'

class ClientTest < Minitest::Test

  def test_new_empty_client
    c = EmptyClient.new("http://localhost:3000")
    refute_nil c
    refute_nil c.instance_variable_get(:@conn) # make sure that connection was assigned
    assert_equal "EmptyClient", c.service_full_name
  end

  def test_new_with_invalid_url
    assert_raises URI::InvalidURIError do
      EmptyClient.new("lulz")
    end
  end

  def test_new_with_invalid_faraday_connection
    assert_raises ArgumentError do
      EmptyClient.new(something: "else")
    end
  end

  def test_simple_foo_client
    c = FooClient.new(fake_conn("/Foo/Foo") {|req|
      [200, protoheader, proto(Foo, foo: "out")]
    })
    resp = c.call_rpc(:Foo, foo: "in")
    assert_nil resp.error
    refute_nil resp.data
    assert_equal "out", resp.data.foo
  end

  def test_simple_foo_client_error
    c = FooClient.new(fake_conn("/Foo/Foo") {|req|
      [400, {}, json(code: "invalid_argument", msg: "dont like empty")]
    })
    resp = c.call_rpc(:Foo, foo: "")
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :invalid_argument, resp.error.code
    assert_equal "dont like empty", resp.error.msg
  end

  def test_simple_foo_client_serialization_exception
    c = FooClient.new(fake_conn("/Foo/Foo") {|req|
      [200, protoheader, "badstuff"]
    })
    assert_raises Google::Protobuf::ParseError do
      resp = c.call_rpc(:Foo, foo: "in")
    end
  end




  # Test Helpers
  # ------------

  def protoheader
    {'Content-Type' => 'application/protobuf'}
  end

  def proto(clss, attrs)
    clss.encode(clss.new(attrs))
  end

  def json(attrs)
    JSON.generate(attrs)
  end

  # Helper to easily make faraday test connections with profobuf responses or errors.
  def fake_conn(path)
    Faraday.new do |conn|
      conn.adapter :test do |stub|
        stub.post(path) do |env|
          yield(env)
        end
      end
    end
  end

end
