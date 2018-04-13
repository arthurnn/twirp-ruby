require 'faraday'

require_relative 'client_resp'
require_relative 'encoding'
require_relative 'error'
require_relative 'service_dsl'

module Twirp

  class Client

    # DSL to define a client with package, service and rpcs.
    extend ServiceDSL

    class << self # class methods

      # DSL (alternative) to define a client from a Service class.
      def client_for(svclass)
        package svclass.package_name
        service svclass.service_name
        svclass.rpcs.each do |rpc_method, rpcdef|
          rpc rpc_method, rpcdef[:input_class], rpcdef[:output_class], ruby_method: rpcdef[:ruby_method]
        end
      end

      # Hook for ServiceDSL#rpc to define a new method client.<ruby_method>(input, opts).
      def rpc_define_method(rpcdef)
        unless method_defined? rpcdef[:ruby_method] # collision with existing rpc method
          define_method rpcdef[:ruby_method] do |input|
            rpc(rpcdef[:rpc_method], input)
          end
        end
      end

      def error_from_response(resp)
        status = resp.status

        if is_http_redirect? status
          return twirp_redirect_error(status, resp.headers['Location'])
        end

        err_attrs = nil
        begin
          err_attrs = Encoding.decode_json(resp.body)
        rescue JSON::ParserError
          return twirp_error_from_intermediary(status, "Response is not JSON", resp.body)
        end

        code = err_attrs["code"]
        if code.to_s.empty?
          return twirp_error_from_intermediary(status, "Response is JSON but it has no \"code\" attribute", resp.body)
        end
        code = code.to_s.to_sym
        if !Twirp::Error.valid_code?(code)
          return Twirp::Error.internal("Invalid Twirp error code: #{code}", invalid_code: code.to_s, body: resp.body)
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

        Twirp::Error.new(code, code.to_s, {
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

      def rpc_path(service_full_name, rpc_method)
        "/twirp/#{service_full_name}/#{rpc_method}"
      end

    end # class << self



    # Init with a Faraday connection, or a base_url that is used in a default connection.
    # Clients use Content-Type="application/protobuf" by default. For JSON clinets use :content_type => "application/json".
    def initialize(conn, opts={})
      @conn = case conn
        when String then Faraday.new(url: conn) # init with hostname
        when Faraday::Connection then conn      # init with connection
        else raise ArgumentError.new("Invalid conn #{conn.inspect}. Expected String hostname or Faraday::Connection")
      end

      @content_type = (opts[:content_type] || Encoding::PROTO)
      if !Encoding.valid_content_type?(@content_type)
        raise ArgumentError.new("Invalid content_type #{@content_type.inspect}. Expected one of #{Encoding.valid_content_types.inspect}")
      end

      @service_full_name = self.class.service_full_name # defined through DSL
    end

    # Make a remote procedure call to a defined rpc_method. The input can be a Proto message instance,
    # or the attributes (Hash) to instantiate it. Returns a ClientResp instance with an instance of
    # output_class, or a Twirp::Error. The input and output classes are the ones configued with the rpc DSL.
    # If rpc_method was not defined with the rpc DSL then a response with a bad_route error is returned instead.
    def rpc(rpc_method, input)
      rpcdef = self.class.rpcs[rpc_method.to_s]
      if !rpcdef
        return ClientResp.new(nil, Twirp::Error.bad_route("rpc not defined on this client"))
      end

      input = rpcdef[:input_class].new(input) if input.is_a? Hash
      body = Encoding.encode(input, rpcdef[:input_class], @content_type)

      resp = @conn.post do |r|
        r.url Client.rpc_path(@service_full_name, rpc_method)
        r.headers['Content-Type'] = @content_type
        r.headers['Accept'] = @content_type
        r.body = body
      end

      if resp.status != 200
        return ClientResp.new(nil, self.class.error_from_response(resp))
      end

      if resp.headers['Content-Type'] != @content_type
        return ClientResp.new(nil, Twirp::Error.internal("Expected response Content-Type #{@content_type.inspect} but found #{resp.headers['Content-Type'].inspect}"))
      end

      data = Encoding.decode(resp.body, rpcdef[:output_class], @content_type)
      return ClientResp.new(data, nil)
    end

  end
end
