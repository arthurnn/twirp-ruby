module Twirp
  class Service

    class << self

      # Configure service package name.
      def package(package_name)
        @package_name = package_name.to_s
      end

      # Configure service name.
      def service(service_name)
        @service_name = service_name.to_s
      end

      # Configure service routing to handle rpc calls.
      def rpc(method_name, request_class, response_class, opts)
        if !request_class.is_a?(Class)
          raise ArgumentError.new("request_class must be a Protobuf Message class")
        end 
        if !response_class.is_a?(Class)
          raise ArgumentError.new("response_class must be a Protobuf Message class")
        end
        if !opts || !opts[:handler_method]
          raise ArgumentError.new("opts[:handler_method] is mandatory")
        end

        @rpcs ||= {}
        @rpcs[method_name.to_s] = {
          request_class: request_class,
          response_class: response_class,
          handler_method: opts[:handler_method],
        }
      end

      # Get configured package name as String.
      # And empty value means that there's no package.
      def package_name
        @package_name.to_s
      end

      # Get configured service name as String.
      # If not configured, it defaults to the class name.
      def service_name
        sname = @service_name.to_s
        sname.empty? ? self.name : sname
      end

      # Get configured metadata for rpc methods.
      def rpcs
        @rpcs || {}
      end

      # Path prefix that should be used to route requests to this service.
      # It is based on the package and service name, in the expected Twirp URL format.
      # The full URL would be: {BaseURL}/path_prefix/{MethodName}.
      def path_prefix
        "/twirp/#{service_full_name}" # e.g. "twirp/Haberdasher"
      end

      # Service full name uniquelly identifies the service.
      # It is the service name prefixed by the package name,
      # for example "my.package.Haberdasher", or "Haberdasher" (if no package).
      def service_full_name
        package_name.empty? ? service_name : "#{package_name}.#{service_name}"
      end

    end # class << self


    # Instantiate a new service with a handler.
    # The handler must implemnt all rpc methods required by this service.
    def initialize(handler)
      self.class.rpcs.each do |method_name, rpc|
        if !handler.respond_to? rpc[:handler_method]
          raise ArgumentError.new("Handler must respond to .#{rpc[:handler_method]}(input) in order to handle the message #{method_name}.")
        end
      end
      @handler = handler
    end
    # Register a before hook (not implemented)
    def before(&block)
      # TODO... and also after hooks
    end

    # Rack app handler.
    def call(env)
      req = Rack::Request.new(env)
      rpc, content_type, bad_route = parse_rack_request(req)
      if bad_route
        return error_response(bad_route)
      end
        
      proto_req = decode_request(rpc[:request_class], content_type, req.body.read)
      begin
        resp = @handler.send(rpc[:handler_method], proto_req)
        return rack_response_from_handler(rpc, content_type, resp)
      rescue Twirp::Exception => twerr
        error_response(twerr)
      end
    end

    def path_prefix
      self.class.path_prefix
    end

    def service_full_name
      self.class.service_full_name
    end

  private

    def parse_rack_request(req)
      if req.request_method != "POST"
        return nil, nil, bad_route_error("HTTP request method must be POST", req)
      end

      content_type = req.env["CONTENT_TYPE"]
      if content_type != "application/json" && content_type != "application/protobuf"
        return nil, nil, bad_route_error("unexpected Content-Type: #{content_type.inspect}. Content-Type header must be one of \"application/json\" or \"application/protobuf\"", req)
      end
      
      path_parts = req.fullpath.split("/")
      if path_parts.size < 4 || path_parts[-2] != self.service_full_name || path_parts[-3] != "twirp"
        return nil, nil, bad_route_error("Invalid route. Expected format: POST {BaseURL}/twirp/(package.)?{Service}/{Method}", req)
      end
      method_name = path_parts[-1]

      rpc = self.class.rpcs[method_name]
      if !rpc
        return nil, nil, bad_route_error("rpc method not found: #{method_name.inspect}", req)
      end

      return rpc, content_type, nil
    end

    def rack_response_from_handler(rpc, content_type, resp)
      if resp.is_a? Twirp::Error
        return error_response(resp)
      end

      if resp.is_a? Hash # allow handlers to return just the attributes
        resp = rpc[:response_class].new(resp)
      end

      if !resp # allow handlers to return nil or false as a reponse with zero-values
        resp = rpc[:response_class].new
      end

      encoded_resp = encode_response(rpc[:response_class], content_type, resp)
      success_response(content_type, encoded_resp)
    end

    def decode_request(request_class, content_type, body)
      case content_type
      when "application/json"
        request_class.decode_json(body)
      when "application/protobuf"
        request_class.decode(body)
      end
    end

    def encode_response(response_class, content_type, resp)
      case content_type
      when "application/json"
        response_class.encode_json(resp)
      when "application/protobuf"
        response_class.encode(resp)
      end
    end

    def success_response(content_type, encoded_resp)
      [200, {'Content-Type' => content_type}, [encoded_resp]]
    end

    def error_response(twirp_error)
      status = Twirp::ERROR_CODES_TO_HTTP_STATUS[twirp_error.code]
      headers = {'Content-Type' => 'application/json'} 
      resp_body = twirp_error.to_json
      [status, headers, [resp_body]]
    end

    def bad_route_error(msg, req)
      meta_invalid_route = "#{req.request_method} #{req.fullpath}"
      Twirp::Error.new(:bad_route, msg, "twirp_invalid_route" => meta_invalid_route)
    end

  end
end
