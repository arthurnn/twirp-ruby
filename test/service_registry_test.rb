require 'minitest/autorun'

require_relative '../lib/twirp/service_registry'

# This is testing Twirp.register_service internals, to make sure it works as expected.
class TestRegisterService < Minitest::Test
  def setup
    Twirp.clear_services! # make sure the registry is clean
  end

  def test_register_valid_service
    Twirp["foopkg.FooService"] = fake_service
    assert_equal fake_service, Twirp["foopkg.FooService"]
  end

  def test_clear_services
    Twirp["foopkg.FooService"] = fake_service
    Twirp.clear_services!
    assert_nil Twirp["foopkg.FooService"]
  end


private

  def fake_service
    "fake" # service type not validate at this moment
  end

end
