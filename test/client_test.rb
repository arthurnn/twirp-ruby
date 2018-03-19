require 'minitest/autorun'
require 'rack/mock'
require 'google/protobuf'
require 'json'

require_relative '../lib/twirp'

class ClientTest < Minitest::Test

  def test_dummy
    c = Twirp::Client.new(url: "localhost:3000")
    refute_nil c 
  end

end
