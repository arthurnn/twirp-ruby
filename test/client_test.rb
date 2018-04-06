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

  def test_fake_request
    conn = fake_conn "/Foo/Foo", resp: Foo.new(foo: "out")
    c = FooClient.new(conn)
    resp = c.call_rpc(:Foo, foo: "in")
    assert_nil resp.error
    refute_nil resp.data
    assert_equal "out", resp.data.foo
  end


  # Test Helpers
  # ------------

  # Helper to easily make faraday test connections with profobuf responses or errors.
  def fake_conn(path, opts={})
    opts[:status] ||= 200

    unless opts[:resp].is_a?(String) # strings are used as literal response bodies, e.g. for JSON errors
      opts[:resp] = opts[:resp].class.encode(opts[:resp])
      opts[:headers] ||= {'Content-Type' => 'application/protobuf'}
    end

    Faraday.new do |conn|
      conn.adapter :test do |stub|
        stub.post(path) do |env|
          [opts[:status], opts[:headers], opts[:resp]]
        end
      end
    end
  end

end
