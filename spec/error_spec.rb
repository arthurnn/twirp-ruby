require 'minitest'
require 'minitest/autorun'

require_relative '../lib/twirp/error'

describe Twirp::ERROR_CODES do
  it "has 17 codes" do
    Twirp::ERROR_CODES.size.must_equal 17 
  end
  it "all codes are Symbols" do
    Twirp::ERROR_CODES.each do |code|
      code.must_be_instance_of Symbol
    end
  end
  it "includes :internal, :not_found, :invalid_argument" do
    Twirp::ERROR_CODES.must_include :internal
    Twirp::ERROR_CODES.must_include :not_found
    Twirp::ERROR_CODES.must_include :invalid_argument
  end
end

describe Twirp::ERROR_CODES_TO_HTTP_STATUS do
  it "is a map with all 17 codes" do
    Twirp::ERROR_CODES_TO_HTTP_STATUS.size.must_equal 17 
  end
  it "maps :not_found to 404" do
    Twirp::ERROR_CODES_TO_HTTP_STATUS[:not_found].must_equal 404
  end
  it "maps :internal to 500" do
    Twirp::ERROR_CODES_TO_HTTP_STATUS[:internal].must_equal 500
  end
  it "can be used to check if a code is invalid, where it returns nil" do
    Twirp::ERROR_CODES_TO_HTTP_STATUS[:invalid_fdsafda].must_be_nil
    Twirp::ERROR_CODES_TO_HTTP_STATUS[500].must_be_nil
    Twirp::ERROR_CODES_TO_HTTP_STATUS[nil].must_be_nil
    Twirp::ERROR_CODES_TO_HTTP_STATUS["not_found"].must_be_nil # string checks not supported, please use symbols
  end
end

describe Twirp::Error do

  describe "new" do
    it "initializes with a valid code and a message" do
      err = Twirp::Error.new(:internal, "woops")
      err.code.must_equal :internal
      err.msg.must_equal "woops"
      err.meta.must_equal({}) # empty
    end

    it "initializes with valid metadata" do
      err = Twirp::Error.new(:internal, "woops", "meta" => "data", "for this" => "error")
      assert_equal(err.meta["meta"], "data")
      err.meta["for this"].must_equal "error"
      err.meta["something else"].must_be_nil
    end

    it "validates code" do
      proc do
        Twirp::Error.new(:invalid_code, "woops")
      end.must_raise ArgumentError
    end

    it "validates meta" do
      Twirp::Error.new(:internal, "woops") # ensure the base case doesn't error

      proc do
        Twirp::Error.new(:internal, "woops", non_string: "metadata")
      end.must_raise ArgumentError

      proc do
        Twirp::Error.new(:internal, "woops", "string key" => :non_string_value)
      end.must_raise ArgumentError

      proc do
        Twirp::Error.new(:internal, "woops", "valid key" => "valid val", "bad_one" => 666)
      end.must_raise ArgumentError
    end
  end

  describe "as_json" do
    it "returns a hash with attributes" do
      err = Twirp::Error.new(:internal, "err msg", "key" => "val")
      err.as_json.must_equal({code: :internal, msg: "err msg", meta: {"key" => "val"}})
    end
    it "skips meta if not included" do
      err = Twirp::Error.new(:internal, "err msg")
      err.as_json.must_equal({code: :internal, msg: "err msg"})
    end
  end

end
