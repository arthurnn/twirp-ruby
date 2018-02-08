module Twirp

  class Service

    def initialize(attrs)
      # TODO: validate inputs (report good error messages if not properly initialized)
      @service_name = attrs[:service_name]
      @package = attrs[:package]
      @rpc_types = attrs[:rpc_types] # classes to serialize request and responses for each rpc. TODO: ensure keys are Strings, etc.

      @rpc_handlers = {} # handlers for each rpc
    end

    # Register an rpc handler.
    def rpc(method_name, &block)
      # TODO: validate method_name (included in @rpc_types?) and block (arity), report good error messages
      @rpc_handlers[method_name.to_s] = block
    end

    # Register a before hook.
    def before(&block)
      # TODO... and also after hooks
    end

    def path_prefix
      "/twirp/@{@package}.#{@service_name}"
    end

    def route_request(http_req)
      # Parse request
      method_name = http_req.fullpath[path_prefix.length+1..-1]
      rpc_type = @rpc_types[method_name]
      request_class = 
      response_class = rpc_type[:response_class]
      content_type = http_req.env["CONTENT_TYPE"] # TODO: validate

      params = decode_request(rpc_type[:request_class], content_type, http_req.body.read)

      # Handle request
      handler = @rpc_handlers[method_name]
      resp = handler.call(params) # TODO: add begin-resque to hadnle exceptions

      # Error responses
      if resp.is_a? Twirp::Error
        status = Twirp::ERROR_CODES_TO_HTTP_STATUS[resp.code]
        return [status, {'Content-Type' => 'application/json'}, [resp.to_json]]
      end

      # Encode response
      if resp.is_a? Hash # allow handlers to respond with just the attributes
        resp = response_class.new(resp)
      end
      encoded_resp = encode_response(response_class, content_type, resp)

      return ['200', {'Content-Type' => content_type}, [encoded_resp]]
    end

    def decode_request(request_class, content_type, body)
      case content_type
      when "application/json"
        request_class.decode_json(body)
      when "application/protobuf"
        request_type.decode(body)
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

    # Return a proc that can be mounter as a Rack app to serve HTTP traffic
    def rack_handler
      return Proc.new do |env|
        req = Rack::Request.new(env)
        route_request(req)
      end
    end
  end
end
