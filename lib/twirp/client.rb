require 'faraday'
require 'json'

require_relative "error"
require_relative "service_dsl"

module Twirp

  class Client

    # DSL to define a client with package, service and rpcs.
    extend ServiceDSL
    
    # DSL (alternative) to define a client from the service class.
    def self.client_for(svclass)
      package svclass.package_name
      service svclass.service_name
      svclass.rpcs.each do |rpc_method, rpcdef|
        rpc rpc_method, rpcdef[:input_class], rpcdef[:output_class], ruby_method: rpcdef[:ruby_method]
      end
    end

    # When rpc DSL is used, a new method is defined in the client.<ruby_method>(input, opts).
    def self.rpc_define_method(rpcdef)
      define_method rpcdef[:ruby_method] do |input|
        call_rpc(rpcdef[:rpc_method], input)
      end
    end

    def initialize(opts)
      @package = opts[:package] || self.class.package_name
      @service = opts[:service] || self.class.service_name
      @conn = opts[:conn] ||
        Faraday.new(url: opts[:url] || "http://localhost:3000") # default Webrick port
    end

    def service_path
      @package.empty? ? @service : "#{@package}.#{@service}"
    end

    def rpc_path(rpc_method)
      "/#{service_path}/#{rpc_method}"
    end

    def call_rpc(rpc_method, input)
      rpcdef = self.class.rpcs[:rpc_method]
      if !rpcdef
        return ClientResp.new(nil, Twirp::Error.bad_route("rpc not defined on this client"))
      end

      input = env[:input_class].new(input) if input.is_a? Hash
      body = env[:input_class].encode(input)

      resp = @conn.post do |r|
        r.url rpc_path(rpc_method)
        r.headers['Content-Type'] = 'application/protobuf'
        r.body = body
      end

      if resp.status != 200
        return ClientResp.new(nil, error_from_response(resp))
      end

      data = env[:output_class].decode(resp.body)
      return ClientResp.new(data, nil)
    end

    def error_from_response(resp)
      status = resp.status

      # Unexpected redirect: it must be an error from an intermediary.
      # Twirp clients don't follow redirects automatically, Twirp only handles
      # POST requests, redirects should only happen on GET and HEAD requests.
      if is_http_redirect(status)
        location = resp.headers["Location"]
        return twirp_error_from_intermediary(status, "unexpected HTTP status code #{resp.status} received, redirect from location=#{location}", location)
      end
      
      err_attrs = nil
      begin
        err_attrs = JSON.parse(resp.body)
      rescue JSON::ParserError => e
        return twirp_error_from_intermediary(status, "Error from intermediary with HTTP status code #{status}", resp.body)
      end

      code = err_attrs["code"]
      if code.to_s.empty?
        return twirp_error_from_intermediary(status, "Error from intermediary with status #{status}. The response is JSON but it has no code key.", resp.body)
      end
      if !Twirp.valid_error_code?(code.to_s.to_sym)
        return Twirp::Error.internal("Invalid Twirp error code #{code} in server error response", invalid_code: code)
      end

      Twirp::Error.new(code, err_attrs["msg"], err_attrs["meta"])
    end

    # Error that was caused by an intermediary proxy like a load balancer.
    # The HTTP errors code from non-twirp sources is mapped to equivalent twirp errors.
    # The mapping is similar to gRPC: https://github.com/grpc/grpc/blob/master/doc/http-grpc-status-mapping.md.
    # Returned twirp Errors have some additional metadata for inspection.
    def twirp_error_from_intermediary(status, msg, bodyOrLocation)
      code =
        if is_http_redirect? status # 3xx
          :internal
        else
          case status
          when 400 then :internal
          when 401 then :unauthenticated
          when 403 then :permission_denied
          when 404 then :bad_route
          when 429, 502, 503, 504 then :unavailable
          else :unknown
          end
        end

      twerr = Twirp::Error.new(code, msg, {
        http_error_from_intermediary: "true", # to easily know if this error was from intermediary
        status_code: status.to_s,
        (is_http_redirect?(status) ? :location : :body) => bodyOrLocation,
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
