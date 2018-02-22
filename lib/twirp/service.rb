require "json"

module Twirp
  class Service

    class << self

      # Configure service package name.
      def package(name)
        @package_name = name.to_s
      end

      # Configure service name.
      def service(name)
        @service_name = name.to_s
      end

      # Configure service routing to handle rpc calls.
      def rpc(rpc_method, input_class, output_class, opts)
        raise ArgumentError.new("input_class must be a Protobuf Message class") unless input_class.is_a?(Class) 
        raise ArgumentError.new("output_class must be a Protobuf Message class") unless output_class.is_a?(Class)
        raise ArgumentError.new("opts[:handler_method] is mandatory") unless opts && opts[:handler_method]

        @rpcs ||= {}
        @rpcs[rpc_method.to_s] = {
          rpc_method: rpc_method.to_s,
          input_class: input_class,
          output_class: output_class,
          handler_method: opts[:handler_method].to_s,
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

      # Service full name uniquelly identifies the service.
      # It is the service name prefixed by the package name,
      # for example "my.package.Haberdasher", or "Haberdasher" (if no package).
      def service_full_name
        package_name.empty? ? service_name : "#{package_name}.#{service_name}"
      end

      # Path prefix that should be used to route requests to this service.
      # It is based on the package and service name, in the expected Twirp URL format.
      # The full URL would be: {BaseURL}/path_prefix/{MethodName}.
      def path_prefix
        "/twirp/#{service_full_name}" # e.g. "twirp/Haberdasher"
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

    # Setup a before hook on this service.
    # Before hooks are called after the request has been successfully routed to a method.
    # If multiple hooks are added, they are run in the same order as declared.
    # The hook is a block that accepts 3 parameters:
    #  * rpc_method: rpc method as defined in the proto file.
    #  * input: Protobuf message object that will be passed to the handler method.
    #  * request: the raw Rack::Request
    #
    # If the before hook returns a Twirp::Error then the request is inmediatly
    # canceled, the handler method is not called, and that error is returned instead.
    # Any other return value from the hook is ignored (nil or otherwise).
    # If an excetion is raised from the hook, it will be handled just like exceptions
    # raised from handler methods: they will trigger the error hook and wrapped with a Twirp::Error.
    #
    # Usage Example:
    #
    #    handler = ExampleHandler.new
    #    svc = ExampleService.new(handler)
    #
    #    svc.before do |rpc_method, input, request|
    #      if request.get_header "Force-Error"
    #        return Twirp.canceled_error("failed as recuested sir")
    #      end
    #      request.env["example_service.before_succeed"] = true # can be later accessed on the handler method
    #    end
    #
    #    svc.before handler.method(:before) # you can also delegate the hook to the handler (to reuse helpers, etc)
    #
    def before(&block)
      (@before_hooks ||= []) << block
    end

    # Hook code that is run after method calls that return a Twirp::Error,
    # or raise an exception ...
    def error(&block)
      # TODO ...
    end

    # Rack app handler.
    def call(env)
      request = Rack::Request.new(env)
      rpc, content_type, bad_route = route_request(request)
      if bad_route
        return error_response(bad_route)
      end
      input = decode_request(rpc[:input_class], content_type, request.body.read)

      begin
        if twerr = run_before_hooks(rpc[:rpc_method], input, request)
          error_response(twerr)
        end

        handler_output = @handler.send(rpc[:handler_method], input)
        if handler_output.is_a? Twirp::Error
          return error_response(handler_output)
        end

        encoded_resp = encode_response_from_handler(rpc, content_type, handler_output)
        success_response(content_type, encoded_resp)

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

    def route_request(request)
      if request.request_method != "POST"
        return nil, nil, bad_route_error("HTTP request method must be POST", request)
      end

      content_type = request.env["CONTENT_TYPE"]
      if content_type != "application/json" && content_type != "application/protobuf"
        return nil, nil, bad_route_error("unexpected Content-Type: #{content_type.inspect}. Content-Type header must be one of \"application/json\" or \"application/protobuf\"", request)
      end
      
      path_parts = request.fullpath.split("/")
      if path_parts.size < 4 || path_parts[-2] != self.service_full_name || path_parts[-3] != "twirp"
        return nil, nil, bad_route_error("Invalid route. Expected format: POST {BaseURL}/twirp/(package.)?{Service}/{Method}", request)
      end
      method_name = path_parts[-1]

      rpc = self.class.rpcs[method_name]
      if !rpc
        return nil, nil, bad_route_error("rpc method not found: #{method_name.inspect}", request)
      end

      return rpc, content_type, nil
    end

    def decode_request(input_class, content_type, body)
      case content_type
      when "application/json"
        input_class.decode_json(body)
      when "application/protobuf"
        input_class.decode(body)
      end
    end

    # Before hooks are run in order after the request has been successfully routed to a Method.
    def run_before_hooks(rpc_method, input, request)
      return unless @before_hooks
      @before_hooks.each do |hook|
        twerr = hook.call(rpc_method, input, request)
        return twerr if twerr && twerr.is_a?(Twirp::Error)
      end
      nil
    end

    def encode_response_from_handler(rpc, content_type, resp)
      proto_class = rpc[:output_class]

      # Handlers may return just the attributes
      if resp.is_a? Hash
        resp = proto_class.new(resp)
      end

      # Handlers may return nil, that should be converted to zero-values
      if !resp
        resp = proto_class.new
      end

      case content_type
      when "application/json"
        proto_class.encode_json(resp)
      when "application/protobuf"
        proto_class.encode(resp)
      end
    end

    def success_response(content_type, encoded_resp)
      [200, {'Content-Type' => content_type}, [encoded_resp]]
    end

    def error_response(twirp_error)
      status = Twirp::ERROR_CODES_TO_HTTP_STATUS[twirp_error.code]
      [status, {'Content-Type' => 'application/json'}, [JSON.generate(twirp_error.to_h)]]
    end

    def bad_route_error(msg, req)
      Twirp.bad_route_error msg, twirp_invalid_route: "#{req.request_method} #{req.fullpath}"
    end

  end
end
