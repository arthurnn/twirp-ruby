require "json"

module Twirp

  CONTENT_TYPES = {
    "application/json"     => :json,
    "application/protobuf" => :protobuf,
  }

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

        @base_envs ||= {}
        @base_envs[rpc_method.to_sym] = {
          rpc_method: rpc_method.to_sym,
          input_class: input_class,
          output_class: output_class,
          handler_method: opts[:handler_method].to_sym,
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

      # Base Twirp environment for each rpc method.
      def base_envs
        @base_envs || {}
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
      self.class.base_envs.each do |rpc_method, env|
        hmethod = env[:handler_method]
        if !handler.respond_to?(hmethod)
          raise ArgumentError.new("Handler must respond to .#{hmethod}(input, env) in order to handle the rpc method #{rpc_method}.")
        end
        if handler.method(hmethod).arity != 2
          raise ArgumentError.new("Hanler method #{hmethod} must accept exactly 2 arguments: #{hmethod}(input, env).")
        end
      end

      @handler = handler
    end

    # Setup a before hook on this service.
    # Before hooks are called after the request has been successfully routed to a method.
    # If multiple hooks are added, they are run in the same order as declared.
    # The hook is a block that accepts 3 parameters: (rpc, input, request)
    #  * rpc: rpc data for the current method with info like rpc[:rpc_method] and rpc[:input_class].
    #  * input: Protobuf message object that will be passed to the handler method.
    #  * env: the Twirp environment object that will be passed to the handler method.
    #
    # If the before hook returns a Twirp::Error then the request is inmediatly
    # canceled, the handler method is not called, and that error is returned instead.
    # Any other return value from the hook is ignored (nil or otherwise).
    # If an excetion is raised from the hook the request is also canceled, 
    # and the exception is handled with the error hook (just like exceptions raised from methods).
    #
    # Usage Example:
    #
    #    handler = ExampleHandler.new
    #    svc = ExampleService.new(handler)
    #
    #    svc.before do |rpc, input, env|
    #      if env.get_http_request_header "Force-Error"
    #        return Twirp.canceled_error("failed as recuested sir")
    #      end
    #      env[:before_hook_called] = true # can be later accessed on the handler method
    #      env[:easy_access] = env.rack_request.env["rack.data"] # before hooks can be used to read data from the request
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
    def call(rack_env)
      rack_request = Rack::Request.new(rack_env)
      env, bad_route = route_request(rack_request)
      if bad_route
        return error_response(bad_route)
      end
      input = decode_input(rack_request.body.read, env)

      begin
        twerr = run_before_hooks(input, env)
        if twerr
          return error_response(twerr)
        end

        handler_output = @handler.send(env[:handler_method], input, env)
        if handler_output.is_a? Twirp::Error
          return error_response(handler_output)
        end

        output = output_from_handler(handler_output, env)
        encoded_resp = encode_output(output, env)
        return success_response(encoded_resp, rack_request.get_header("CONTENT_TYPE"), env)

      rescue Twirp::Exception => twerr
        return error_response(twerr)
      end
    end

    def path_prefix
      self.class.path_prefix
    end

    def service_full_name
      self.class.service_full_name
    end


  private

    # Verify that the request can be routed to a valid handler method 
    # and return a touple [env, twerr], with the Twirp environment used by hooks
    # and handler methods, or a Twirp bad_route error if it could not be routed.
    def route_request(rack_request)
      if rack_request.request_method != "POST"
        return nil, bad_route_error("HTTP request method must be POST", rack_request)
      end

      content_type = CONTENT_TYPES[rack_request.get_header("CONTENT_TYPE")]
      if !content_type
        return nil, bad_route_error("unexpected Content-Type: #{rack_request.get_header("CONTENT_TYPE").inspect}. Content-Type header must be one of #{CONTENT_TYPES.keys.inspect}", rack_request)
      end
      
      path_parts = rack_request.fullpath.split("/")
      if path_parts.size < 4 || path_parts[-2] != self.service_full_name || path_parts[-3] != "twirp"
        return nil, bad_route_error("Invalid route. Expected format: POST {BaseURL}/twirp/(package.)?{Service}/{Method}", rack_request)
      end
      method_name = path_parts[-1].to_sym

      base_env = self.class.base_envs[method_name]
      if !base_env
        return nil, bad_route_error("Invalid rpc method #{method_name}", rack_request)
      end

      return base_env.merge({ # base env contains metadata useful for before hooks like :rpc_method and :input_class
        rack_request: rack_request, # should only be accessed by before hooks (that can add more data to the env).
        content_type: content_type, # :json or :protobuf.
        http_response_headers: {},  # can be used by hanlder methods to add response headers.
      }), nil
    end

    def decode_input(body, env)
      case env[:content_type]
      when :protobuf then env[:input_class].decode(body)
      when :json     then env[:input_class].decode_json(body)
      end
    end

    def encode_output(output, env)
      case env[:content_type]
      when :protobuf then env[:output_class].encode(output)
      when :json     then env[:output_class].encode_json(output)
      end
    end

    # Before hooks are run in order after the request has been successfully routed to a Method.
    def run_before_hooks(input, env)
      return unless @before_hooks
      @before_hooks.each do |hook|
        twerr = hook.call(input, env)
        return twerr if twerr && twerr.is_a?(Twirp::Error)
      end
      nil
    end

    def output_from_handler(handler_output, env)
      case handler_output
      when env[:output_class] then handler_output
      when Hash then env[:output_class].new(handler_output)
      when nil then env[:output_class].new # empty output with zero-values
      else
        raise TypeError.new("Unexpected type #{handler_output.class.name} returned by handler.#{env[:handler_method]}(input, env). Expected one of #{env[:output_class].name}, Hash (attributes) or nil (zero-values).")
      end
    end

    def success_response(resp_body, request_content_type, env)
      headers = env[:http_response_headers].merge('Content-Type' => request_content_type)
      [200, headers, [resp_body]]
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
