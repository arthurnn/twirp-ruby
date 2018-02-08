require 'minitest/autorun'

require 'google/protobuf'
require_relative '../lib/twirp'

# Define the proto messages (this what the protoc generator would produce)
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "foopkg.DoFooRequest" do
    optional :foo, :string, 1
  end
  add_message "foopkg.DoFooResponse" do
    optional :bar, :string, 1
  end
end
module FooPkg
  DoFooRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("foopkg.DoFooRequest").msgclass
  DoFooResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("foopkg.DoFooResponse").msgclass
end

class ServiceTest < Minitest::Test
  def test_new_valid_service

    svc = Twirp::Service.new({
      package: "foopkg",
      service_name: "Foo",
      rpc_types: {
        DoFoo: {
          request_class: FooPkg::DoFooRequest,
          response_class: FooPkg::DoFooResponse,
        }
      }
    })
    
    svc.rpc "DoFoo" do |req|
      return {bar: "Hello #{req.foo}"}
    end

    svc.rack_handler
  end

  # TODO send fake HTTP requests, check responses
end
