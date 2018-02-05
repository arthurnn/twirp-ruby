require 'minitest/autorun'

require_relative '../lib/twirp/error'

class TestErrorCodes < Minitest::Test
  
  def test_error_codes
    assert_equal 17, Twirp::ERROR_CODES.size

    # all codes should be symbols
    Twirp::ERROR_CODES.each do |code|
      assert_instance_of Symbol, code
    end

    # check some codes
    assert_includes Twirp::ERROR_CODES, :internal 
    assert_includes Twirp::ERROR_CODES, :not_found
    assert_includes Twirp::ERROR_CODES, :invalid_argument
  end

  def test_codes_to_http_status
    assert_equal 17, Twirp::ERROR_CODES_TO_HTTP_STATUS.size

    assert_equal 404, Twirp::ERROR_CODES_TO_HTTP_STATUS[:not_found]
    assert_equal 500, Twirp::ERROR_CODES_TO_HTTP_STATUS[:internal]

    # nil for invalid_codes
    assert_nil Twirp::ERROR_CODES_TO_HTTP_STATUS[:invalid_fdsafda]
    assert_nil Twirp::ERROR_CODES_TO_HTTP_STATUS[500]
    assert_nil Twirp::ERROR_CODES_TO_HTTP_STATUS[nil]
    assert_nil Twirp::ERROR_CODES_TO_HTTP_STATUS["not_found"] # string checks not supported, please use symbols
  end
end

class TestTwirpError < Minitest::Test

  def test_new_with_valid_code_and_a_message
    err = Twirp::Error.new(:internal, "woops")
    assert_equal :internal, err.code
    assert_equal "woops", err.msg
    assert_equal({}, err.meta) # empty
  end

  def test_new_with_valid_metadata
    err = Twirp::Error.new(:internal, "woops", "meta" => "data", "for this" => "error")
    assert_equal err.meta["meta"], "data"
    assert_equal "error", err.meta["for this"] 
    assert_nil err.meta["something else"]
  end

  def test_invalid_code
    assert_raises ArgumentError do 
      Twirp::Error.new(:invalid_code, "woops")
    end
  end

  def test_invalid_metadata
    Twirp::Error.new(:internal, "woops") # ensure the base case doesn't error

    assert_raises ArgumentError do 
      Twirp::Error.new(:internal, "woops", non_string: "metadata")
    end

    assert_raises ArgumentError do 
      Twirp::Error.new(:internal, "woops", "string key" => :non_string_value)
    end

    assert_raises ArgumentError do 
      Twirp::Error.new(:internal, "woops", "valid key" => "valid val", "bad_one" => 666)
    end
  end

  def test_as_json
    # returns a hash with attributes
    err = Twirp::Error.new(:internal, "err msg", "key" => "val")
    assert_equal({code: :internal, msg: "err msg", meta: {"key" => "val"}}, err.as_json)
  
    # skips meta if not included 
    err = Twirp::Error.new(:internal, "err msg")
    assert_equal({code: :internal, msg: "err msg"}, err.as_json)
  end
end

