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

        @base_envs ||= {}
        @base_envs[rpc_method.to_s] = {
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
        meth = env[:handler_method]
        if !handler.respond_to?(meth)
          raise ArgumentError.new("Handler must respond to .#{meth}(input, env) in order to handle the rpc method #{rpc_method}.")
        end
        if handler.method(meth).arity != 2
          raise ArgumentError.new("Hanler method #{meth} must accept exactly 2 arguments: #{meth}(input, env).")
        end
      end

      @handler = handler
    end

    # Setup a before hook.
    # Before hooks are called after the request has been successfully routed to a method.
    # If multiple hooks are added, they are run in the same order as declared.
    # The hook is a lambda that is called with 2 parameters:
    #  * env: Twirp environment that will be passed to the handler.
    #         It contains data about the routed method like :rpc_method, :input or :input_class.
    #  * rack_env: Rack environment with data from the http request and Rack middleware.
    # 
    # The before hook can read the Rack enviornment to add relevant data into the
    # Twirp environment that is accessible by handler methods.
    #
    # If the before hook returns a Twirp::Error then the request is inmediatly
    # canceled, the handler method is not called, and that error is returned instead.
    # Any other return value from the hook is ignored (nil or otherwise).
    def before(&block)
      (@before_hooks ||= []) << block
    end

    # Setup an after hook.
    # After hooks are always called at the end of the request, both on success or error.
    # The hook is a lambda that is called with the Twirp environment.
    # The environment contains an :output if the response was successfully encoded,
    # or a :twirp_error if the handler method or any before hooks failed with an error.
    #
    # If the after hook returns a Twirp::Error then that error is used in the response.
    # Any other return value fro the hook is ignored (nil or otherwise).
    def after(&block)
      (@after_hooks ||= []) << block
    end

    # Hook code that is run after method calls that return a Twirp::Error,
    # or raise an exception ...
    def error(&block)
      # TODO ...
    end

    # Rack app handler.
    def call(rack_env)
      env, bad_route = route_request(rack_env)
      if bad_route
        return error_response(bad_route, nil, false)
      end

      begin
        if twerr = run_before_hooks(env, rack_env)
          return error_response(twerr, env)
        end

        handler_output = @handler.send(env[:handler_method], env[:input], env)
        if handler_output.is_a? Twirp::Error
          return error_response(handler_output, env)
        end

        env[:output] = output_from_handler(handler_output, env)
        encoded_resp = encode_output(env[:output], env[:output_class], env[:content_type])
        return success_response(encoded_resp, env)

      rescue Twirp::Exception => twerr
        return error_response(twerr, env)
      end
    end

    def path_prefix
      self.class.path_prefix
    end

    def service_full_name
      self.class.service_full_name
    end


  private

    def route_request(rack_env)
      rack_request = Rack::Request.new(rack_env)

      if rack_request.request_method != "POST"
        return nil, bad_route_error("HTTP request method must be POST", rack_request)
      end

      content_type = rack_request.get_header("CONTENT_TYPE")
      if content_type != "application/json" && content_type != "application/protobuf"
        return nil, bad_route_error("unexpected Content-Type: #{content_type.inspect}. Content-Type header must be one of application/json or application/protobuf", rack_request)
      end
      
      path_parts = rack_request.fullpath.split("/")
      if path_parts.size < 4 || path_parts[-2] != self.service_full_name || path_parts[-3] != "twirp"
        return nil, bad_route_error("Invalid route. Expected format: POST {BaseURL}/twirp/(package.)?{Service}/{Method}", rack_request)
      end
      method_name = path_parts[-1]

      base_env = self.class.base_envs[method_name]
      if !base_env
        return nil, bad_route_error("Invalid rpc method #{method_name.inspect}", rack_request)
      end

      input = nil
      begin
        input = decode_input(rack_request.body.read, base_env[:input_class], content_type)
      rescue => e
        return nil, bad_route_error("Invalid request body for rpc method #{method_name.inspect} with Content-Type=#{content_type}", rack_request)
      end
      
      env = base_env.merge({
        content_type: content_type,
        input: input,
        http_response_headers: {},
      })

      return env, nil
    end

    def decode_input(body, input_class, content_type)
      case content_type
      when "application/protobuf" then input_class.decode(body)
      when "application/json"     then input_class.decode_json(body)
      end
    end

    def encode_output(output, output_class, content_type)
      case content_type
      when "application/protobuf" then output_class.encode(output)
      when "application/json"     then output_class.encode_json(output)
      end
    end

    def run_before_hooks(env, rack_env)
      return unless @before_hooks
      @before_hooks.each do |hook|
        twerr = hook.call(env, rack_env)
        return twerr if twerr && twerr.is_a?(Twirp::Error)
      end
      nil
    end

    def run_after_hooks(env)
      return unless @after_hooks
      @after_hooks.each do |hook|
        twerr = hook.call(env)
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

    def success_response(resp_body, env)
      if twerr = run_after_hooks(env)
        return error_response(twerr)
      end
      
      headers = env[:http_response_headers].merge('Content-Type' => env[:content_type])
      [200, headers, [resp_body]]
    end

    def error_response(twirp_error, env, should_run_after_hooks = true)
      if should_run_after_hooks
        env[:twirp_error] = twirp_error
        if twerr = run_after_hooks(env)
          return error_response(twerr, false)
        end
      end

      status = Twirp::ERROR_CODES_TO_HTTP_STATUS[twirp_error.code]
      headers = {'Content-Type' => 'application/json'}
      resp_body = JSON.generate(twirp_error.to_h)
      [status, headers, [resp_body]]
    end

    def bad_route_error(msg, req)
      Twirp::Error.bad_route msg, twirp_invalid_route: "#{req.request_method} #{req.fullpath}"
    end

  end
end
