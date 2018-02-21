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
        if package_name.empty?
          service_name # e.g. "Haberdasher"
        else
          "#{package_name}.#{service_name}" # e.g. "the.haberdasher.pkg.Haberdasher"
        end
      end

    end # class << self


    # Instantiate a new service with a handler.
    # The handler must implemnt all rpc methods required by this service.
    def initialize(handler)
      # validate that the handler reponds to all expected methods
      self.class.rpcs.each do |method_name, rpc|
        if !handler.respond_to? rpc[:handler_method]
          raise ArgumentError.new("Handler must respond to .#{rpc[:handler_method]}(req) in order to handle the message #{method_name}.")
        end
      end

      @handler = handler
    end

    # path prefix that can be used to mount this service
    def path_prefix
      self.class.path_prefix
    end

    # Register a before hook (not implemented)
    def before(&block)
      # TODO... and also after hooks
    end

    # Rack app handler.
    def call(env)
      req = Rack::Request.new(env)

      if req.request_method != "POST"
        return error_response(bad_route_error("Only POST method is allowed", req))
      end
      
      method_name = req.fullpath.split("/").last
      rpc_method = self.class.rpcs[method_name]
      if !rpc_method
        return error_response(bad_route_error("rpc method not found: #{method_name.inspect}", req))
      end

      request_class = rpc_method[:request_class]
      response_class = rpc_method[:response_class]

      content_type = req.env["CONTENT_TYPE"]
      req_msg = decode_request(rpc_method[:request_class], content_type, req.body.read)
      if !req_msg
        return error_response(bad_route_error("unexpected Content-Type: #{content_type.inspect}", req))
      end

      # Handle Twirp request
      # TODO: wrap with begin-rescue block
      resp_msg = @handler.send(rpc_method[:handler_method], req_msg)

      if resp_msg.is_a? Twirp::Error
        return error_response(resp_msg)
      end

      if resp_msg.is_a? Hash # allow handlers to respond with just the attributes
        resp_msg = response_class.new(resp_msg)
      end
      encoded_resp = encode_response(response_class, content_type, resp_msg)

      return [200, {'Content-Type' => content_type}, [encoded_resp]]

      # TODO: add rescue for any error in the method, wrap with Twith error
    end


  private

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
