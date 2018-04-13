require_relative 'client'

module Twirp

  # Convenience class to call any rpc method with dynamic json attributes, without a service definition.
  # This is useful to test a service before doing any code-generation.
  class ClientJSON < Twirp::Client

    def initialize(conn, opts={})
      super(conn, opts)

      package = opts[:package].to_s
      service = opts[:service].to_s
      raise ArgumentError.new("Missing option :service") if service.empty?
      @service_full_name = package.empty? ? service : "#{package}.#{service}"
    end

    # This implementation does not use the defined Protobuf messages to serialize/deserialize data;
    # the request attrs can be anything and the response data is always a plain Hash of attributes.
    def rpc(rpc_method, attrs={})
      body = Encoding.encode_json(attrs)

      resp = self.class.make_http_request(@conn, @service_full_name, rpc_method, Encoding::JSON, body)
      if resp.status != 200
        return ClientResp.new(nil, self.class.error_from_response(resp))
      end

      data = Encoding.decode_json(resp.body)
      return ClientResp.new(data, nil)
    end

  end
end
