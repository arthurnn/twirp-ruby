require 'minitest'
require 'minitest/autorun'

require_relative '../lib/twirp/error'

describe Twirp::ERROR_CODES do
  it "is a list of Symbols" do
    Twirp::ERROR_CODES.each do |code|
      code.must_be_instance_of Symbol
    end
  end
end

describe Twirp::Error do
  
  describe "new" do

    it "initializes with a valid code and a message" do
      err = Twirp::Error.new(:internal, "woops")
      err.code.must_equal :internal
      err.msg.must_equal "woops"
    end

  end

end
