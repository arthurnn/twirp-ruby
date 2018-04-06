require 'faraday'
require 'json'

require_relative "error"
require_relative "service_dsl"

module Twirp

  class Client

    # DSL to define a client with package, service and rpcs.
    extend ServiceDSL

    # DSL (alternative) to define a client from a Service class.
    def self.client_for(svclass)
      package svclass.package_name
      service svclass.service_name
      svclass.rpcs.each do |rpc_method, rpcdef|
        rpc rpc_method, rpcdef[:input_class], rpcdef[:output_class], ruby_method: rpcdef[:ruby_method]
      end
    end

    # Hook for ServiceDSL#rpc to define a new method client.<ruby_method>(input, opts).
    def self.rpc_define_method(rpcdef)
      define_method rpcdef[:ruby_method] do |input|
        call_rpc(rpcdef[:rpc_method], input)
      end
    end

    # Init with a Faraday connection.
    def initialize(conn)
      @conn = case conn
      when String then Faraday.new(url: conn) # init with hostname
      when Faraday::Connection then conn # inith with connection
      else raise ArgumentError.new("Expected hostname String or Faraday::Connection")
      end
    end

    def service_full_name; self.class.service_full_name; end

    def rpc_path(rpc_method)
      "/#{service_full_name}/#{rpc_method}"
    end

    def call_rpc(rpc_method, input)
      rpcdef = self.class.rpcs[rpc_method.to_s]
      if !rpcdef
        return ClientResp.new(nil, Twirp::Error.bad_route("rpc not defined on this client"))
      end

      input = rpcdef[:input_class].new(input) if input.is_a? Hash
      body = rpcdef[:input_class].encode(input)

      resp = @conn.post do |r|
        r.url rpc_path(rpc_method)
        r.headers['Content-Type'] = 'application/protobuf'
        r.body = body
      end

      if resp.status != 200
        return ClientResp.new(nil, error_from_response(resp))
      end

      if resp.headers['Content-Type'] != 'application/protobuf'
        return ClientResp.new(nil, Twirp::Error.internal("Unexpected response Content-Type #{resp.headers['Content-Type'].inspect}. Expected 'application/protobuf'."))
      end

      data = rpcdef[:output_class].decode(resp.body)
      return ClientResp.new(data, nil)
    end

    def error_from_response(resp)
      status = resp.status

      if is_http_redirect? status
        return twirp_redirect_error(status, resp.headers['Location'])
      end

      err_attrs = nil
      begin
        err_attrs = JSON.parse(resp.body)
      rescue JSON::ParserError => e
        return twirp_error_from_intermediary(status, "Response is not JSON", resp.body)
      end

      code = err_attrs["code"]
      if code.to_s.empty?
        return twirp_error_from_intermediary(status, "Response is JSON but it has no \"code\" attribute.", resp.body)
      end
      code = code.to_s.to_sym
      if !Twirp::Error.valid_code?(code)
        return twirp_error_from_intermediary(status, "Invalid Twirp error code #{code}", resp.body)
      end

      Twirp::Error.new(code, err_attrs["msg"], err_attrs["meta"])
    end

    # Error that was caused by an intermediary proxy like a load balancer.
    # The HTTP errors code from non-twirp sources is mapped to equivalent twirp errors.
    # The mapping is similar to gRPC: https://github.com/grpc/grpc/blob/master/doc/http-grpc-status-mapping.md.
    # Returned twirp Errors have some additional metadata for inspection.
    def twirp_error_from_intermediary(status, reason, body)
      code = case status
        when 400 then :internal
        when 401 then :unauthenticated
        when 403 then :permission_denied
        when 404 then :bad_route
        when 429, 502, 503, 504 then :unavailable
        else :unknown
      end

      twerr = Twirp::Error.new(code, code.to_s, {
        http_error_from_intermediary: "true",
        not_a_twirp_error_because: reason,
        status_code: status.to_s,
        body: body.to_s,
      })
    end

    # Twirp clients should not follow redirects automatically, Twirp only handles
    # POST requests, redirects should only happen on GET and HEAD requests.
    def twirp_redirect_error(status, location)
      msg = "Unexpected HTTP Redirect from location=#{location}"
      Twirp::Error.new(:internal, msg, {
        http_error_from_intermediary: "true",
        not_a_twirp_error_because: "Redirects not allowed on Twirp requests",
        status_code: status.to_s,
        location: location.to_s,
      })
    end

    def is_http_redirect?(status)
      status >= 300 && status <= 399
    end

  end

  class ClientResp
    attr_accessor :data
    attr_accessor :error

    def initialize(data, error)
      @data = data
      @error = error
    end
  end
end
