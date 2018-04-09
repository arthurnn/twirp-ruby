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
    assert_equal "EmptyClient", c.instance_variable_get(:@service_full_name)
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

  def test_dsl_method_definition_collision
    # To avoid collisions, the Twirp::Client class should have very few methods
    mthds = Twirp::Client.instance_methods(false)
    assert_equal [:json, :rpc], mthds

    # If one of the methods is being implemented through the DSL, the colision should be avoided
    num_mthds = EmptyClient.instance_methods.size
    EmptyClient.rpc :Json, Example::Empty, Example::Empty, :ruby_method => :json
    assert_equal num_mthds, EmptyClient.instance_methods.size # no new method was added (collision)

    # Make sure that the previous .json method was not modified
    c = EmptyClient.new(conn_stub("/EmptyClient/Json") {|req|
      [200, {}, json(foo: "bar")]
    })
    resp = c.json(:Json, foo: "bar")
    assert_equal "bar", resp.data["foo"]

    # Adding any other rpc would work as expected
    EmptyClient.rpc :Other, Example::Empty, Example::Empty, :ruby_method => :other
    assert_equal num_mthds + 1, EmptyClient.instance_methods.size # new method added
  end


  # Call .rpc on Protobuf client
  # ----------------------------

  def test_proto_success
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [200, protoheader, proto(Example::Hat, inches: 99, color: "red")]
    })
    resp = c.make_hat({})
    assert_nil resp.error
    assert_equal 99, resp.data.inches
    assert_equal "red", resp.data.color
  end

  def test_proto_serialized_request_body_attrs
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      size = Example::Size.decode(req.body) # body is valid protobuf
      assert_equal 666, size.inches

      [200, protoheader, proto(Example::Hat)]
    })
    resp = c.make_hat(inches: 666)
    assert_nil resp.error
    refute_nil resp.data
  end

  def test_proto_serialized_request_body
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      assert_equal "application/protobuf", req.request_headers['Content-Type']

      size = Example::Size.decode(req.body) # body is valid protobuf
      assert_equal 666, size.inches

      [200, protoheader, proto(Example::Hat)]
    })
    resp = c.make_hat(Example::Size.new(inches: 666))
    assert_nil resp.error
    refute_nil resp.data
  end

  def test_proto_twirp_error
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [500, {}, json(code: "internal", msg: "something went wrong")]
    })
    resp = c.make_hat(inches: 1)
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :internal, resp.error.code
    assert_equal "something went wrong", resp.error.msg
  end

  def test_proto_intermediary_plain_error
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [503, {}, 'plain text error from proxy']
    })
    resp = c.make_hat(inches: 1)
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :unavailable, resp.error.code # 503 maps to :unavailable
    assert_equal "unavailable", resp.error.msg
    assert_equal "true", resp.error.meta[:http_error_from_intermediary]
    assert_equal "Response is not JSON", resp.error.meta[:not_a_twirp_error_because]
    assert_equal "plain text error from proxy", resp.error.meta[:body]
  end

  def test_proto_redirect_error
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [300, {'location' => "http://rainbow.com"}, '']
    })
    resp = c.make_hat(inches: 1)
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :internal, resp.error.code
    assert_equal "Unexpected HTTP Redirect from location=http://rainbow.com", resp.error.msg
    assert_equal "true", resp.error.meta[:http_error_from_intermediary]
    assert_equal "Redirects not allowed on Twirp requests", resp.error.meta[:not_a_twirp_error_because]
  end

  def test_proto_missing_response_header
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [200, {}, proto(Example::Hat, inches: 99, color: "red")]
    })
    resp = c.make_hat({})
    refute_nil resp.error
    assert_equal :internal, resp.error.code
    assert_equal 'Expected response Content-Type "application/protobuf" but found nil', resp.error.msg
  end

  def test_error_with_invalid_code
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [500, {}, json(code: "unicorn", msg: "the unicorn is here")]
    })
    resp = c.make_hat({})
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :internal, resp.error.code
    assert_equal "Invalid Twirp error code: unicorn", resp.error.msg
  end

  def test_error_with_no_code
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [500, {}, json(msg: "I have no code of honor")]
    })
    resp = c.make_hat({})
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :unknown, resp.error.code # 500 maps to :unknown
    assert_equal "unknown", resp.error.msg
    assert_equal "true", resp.error.meta[:http_error_from_intermediary]
    assert_equal 'Response is JSON but it has no "code" attribute', resp.error.meta[:not_a_twirp_error_because]
    assert_equal '{"msg":"I have no code of honor"}', resp.error.meta[:body]
  end

  # Call .rpc on JSON client
  # ------------------------

  def test_json_success
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [200, jsonheader, '{"inches": 99, "color": "red"}']
    }, content_type: "application/json")

    resp = c.make_hat({})
    assert_nil resp.error
    assert_equal 99, resp.data.inches
    assert_equal "red", resp.data.color
  end

  def test_json_serialized_request_body_attrs
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      assert_equal "application/json", req.request_headers['Content-Type']
      assert_equal '{"inches":666}', req.body # body is valid json
      [200, jsonheader, '{}']
    }, content_type: "application/json")

    resp = c.make_hat(inches: 666)
    assert_nil resp.error
    refute_nil resp.data
  end

  def test_json_serialized_request_body_object
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      assert_equal "application/json", req.request_headers['Content-Type']
      assert_equal '{"inches":666}', req.body # body is valid json
      [200, jsonheader, '{}']
    }, content_type: "application/json")

    resp = c.make_hat(Example::Size.new(inches: 666))
    assert_nil resp.error
    refute_nil resp.data
  end

  def test_json_error
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [500, {}, json(code: "internal", msg: "something went wrong")]
    }, content_type: "application/json")

    resp = c.make_hat(inches: 1)
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :internal, resp.error.code
    assert_equal "something went wrong", resp.error.msg
  end

  def test_json_missing_response_header
    c = Example::HaberdasherClient.new(conn_stub("/example.Haberdasher/MakeHat") {|req|
      [200, {}, json(inches: 99, color: "red")]
    }, content_type: "application/json")

    resp = c.make_hat({})
    refute_nil resp.error
    assert_equal :internal, resp.error.code
    assert_equal 'Expected response Content-Type "application/json" but found nil', resp.error.msg
  end


  # Directly call .rpc
  # ------------------

  def test_rpc_success
    c = FooClient.new(conn_stub("/Foo/Foo") {|req|
      [200, protoheader, proto(Foo, foo: "out")]
    })
    resp = c.rpc :Foo, foo: "in"
    assert_nil resp.error
    refute_nil resp.data
    assert_equal "out", resp.data.foo
  end

  def test_rpc_error
    c = FooClient.new(conn_stub("/Foo/Foo") {|req|
      [400, {}, json(code: "invalid_argument", msg: "dont like empty")]
    })
    resp = c.rpc :Foo, foo: ""
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :invalid_argument, resp.error.code
    assert_equal "dont like empty", resp.error.msg
  end

  def test_rpc_serialization_exception
    c = FooClient.new(conn_stub("/Foo/Foo") {|req|
      [200, protoheader, "badstuff"]
    })
    assert_raises Google::Protobuf::ParseError do
      c.rpc :Foo, foo: "in"
    end
  end

  def test_rpc_invalid_method
    c = FooClient.new("http://localhost")
    resp = c.rpc :OtherStuff, foo: "noo"
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :bad_route, resp.error.code
  end

  # Call .json
  # ----------

  def test_direct_json_success
    c = Twirp::Client.new(conn_stub("/my.pkg.Talking/Blah") {|req|
      assert_equal "application/json", req.request_headers['Content-Type']
      assert_equal '{"blah1":1,"blah2":2}', req.body # body is json

      [200, {}, json(blah_resp: 3)]
    }, package: "my.pkg", service: "Talking")

    resp = c.json :Blah, blah1: 1, blah2: 2
    assert_nil resp.error
    refute_nil resp.data
    assert_equal 3, resp.data["blah_resp"]
  end

  def test_direct_json_error
    c = Twirp::Client.new(conn_stub("/Foo/Foomo") {|req|
      [400, {}, json(code: "invalid_argument", msg: "dont like empty")]
    }, service: "Foo")

    resp = c.json :Foomo, foo: ""
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :invalid_argument, resp.error.code
    assert_equal "dont like empty", resp.error.msg
  end

  def test_direct_json_bad_route
    c = Twirp::Client.new(conn_stub("/Foo/OtherMethod") {|req|
      [404, {}, 'not here buddy']
    }, service: "Foo")

    resp = c.json :OtherMethod, foo: ""
    assert_nil resp.data
    refute_nil resp.error
    assert_equal :bad_route, resp.error.code
  end


  # Test Helpers
  # ------------

  def protoheader
    {'Content-Type' => 'application/protobuf'}
  end

  def jsonheader
    {'Content-Type' => 'application/json'}
  end

  def proto(clss, attrs={})
    clss.encode(clss.new(attrs))
  end

  def json(attrs)
    JSON.generate(attrs)
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
