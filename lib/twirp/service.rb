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

      # Service name as String.
      # Defaults to the current class name.
      def service_name
        (@service_name || self.name).to_s
      end

      # Base Twirp environments for each rpc method.
      def base_envs
        @base_envs || {}
      end

      # Package and servicce name, as a unique identifier for the service,
      # for example "example.v3.Haberdasher" (package "example.v3", service "Haberdasher").
      # This can be used as a path prefix to route requests to the service, because a Twirp URL is:
      # "#{BaseURL}/#{ServiceFullName}/#{Method]"
      def service_full_name
        package_name.empty? ? service_name : "#{package_name}.#{service_name}"
      end

      # Raise exceptions instead of handling them with exception_raised hooks.
      # Useful during tests to easily debug and catch unexpected exceptions.
      # Default false.
      attr_accessor :raise_exceptions

    end # class << self


    def initialize(handler)
      @handler = handler

      @before = []
      @on_success = []
      @on_error = []
      @exception_raised = []
    end

    def name
      self.class.service_name
    end

    def full_name
      self.class.service_full_name # use to route requests to this servie
    end

    # Setup hook blocks
    def before(&block) @before << block; end
    def on_success(&block) @on_success << block; end
    def on_error(&block) @on_error << block; end
    def exception_raised(&block) @exception_raised << block; end

    # Rack app handler.
    def call(rack_env)
      begin
        env = {}
        bad_route = route_request(rack_env, env)
        return error_response(bad_route, env) if bad_route
      
        @before.each do |hook|
          result = hook.call(rack_env, env)
          return error_response(result, env) if result.is_a? Twirp::Error
        end
          
        output = call_handler(env)
        return error_response(output, env) if output.is_a? Twirp::Error
        return success_response(output, env)

      rescue => e
        raise e if self.class.raise_exceptions
        begin
          @exception_raised.each{|hook| hook.call(e, env) }
        rescue => hook_e
          e = hook_e
        end
        
        twerr = Twirp::Error.internal_with(e)
        return error_response(twerr, env)
      end
    end


  private

    # Parse request and fill env with rpc data.
    # Returns a bad_route error if something went wrong.
    def route_request(rack_env, env)
      rack_request = Rack::Request.new(rack_env)

      if rack_request.request_method != "POST"
        return bad_route_error("HTTP request method must be POST", rack_request)
      end

      content_type = rack_request.get_header("CONTENT_TYPE")
      if content_type != "application/json" && content_type != "application/protobuf"
        return bad_route_error("unexpected Content-Type: #{content_type.inspect}. Content-Type header must be one of application/json or application/protobuf", rack_request)
      end
      env[:content_type] = content_type
      
      path_parts = rack_request.fullpath.split("/")
      if path_parts.size < 3 || path_parts[-2] != self.full_name
        return bad_route_error("Invalid route. Expected format: POST {BaseURL}/#{self.full_name}/{Method}", rack_request)
      end
      method_name = path_parts[-1]

      base_env = self.class.base_envs[method_name]
      if !base_env
        return bad_route_error("Invalid rpc method #{method_name.inspect}", rack_request)
      end
      env.merge!(base_env) # :rpc_method, :input_class, :output_class, :handler_method

      input = nil
      begin
        input = decode_input(rack_request.body.read, env[:input_class], content_type)
      rescue => e
        return bad_route_error("Invalid request body for rpc method #{method_name.inspect} with Content-Type=#{content_type}", rack_request)
      end

      env[:input] = input
      env[:http_response_headers] = {}
      return
    end

    def bad_route_error(msg, req)
      Twirp::Error.bad_route msg, twirp_invalid_route: "#{req.request_method} #{req.fullpath}"
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

    # Call handler method and return a Protobuf Message or a Twirp::Error.
    def call_handler(env)
      handler_method = env[:handler_method]
      if !@handler.respond_to?(handler_method)
        return Twirp::Error.unimplemented("Handler method #{handler_method} is not implemented.")
      end

      out = @handler.send(handler_method, env[:input], env)
      case out
      when env[:output_class], Twirp::Error
        out
      when Hash
        env[:output_class].new(out)
      else
        Twirp::Error.internal("Handler method #{handler_method} expected to return one of #{env[:output_class].name}, Hash or Twirp::Error, but returned #{out.class.name}.")
      end
    end

    def success_response(output, env)
      begin
        env[:output] = output
        @on_success.each{|hook| hook.call(env) }

        headers = env[:http_response_headers].merge('Content-Type' => env[:content_type])
        resp_body = encode_output(output, env[:output_class], env[:content_type])
        [200, headers, [resp_body]]

      rescue => e
        return exception_response(e, env)
      end
    end

    def error_response(twerr, env)
      begin
        @on_error.each{|hook| hook.call(twerr, env) }

        status = Twirp::ERROR_CODES_TO_HTTP_STATUS[twerr.code]
        resp_body = JSON.generate(twerr.to_h)
        [status, error_response_headers, [resp_body]]

      rescue => e
        return exception_response(e, env)
      end
    end

    def exception_response(e, env)
      raise e if self.class.raise_exceptions
      begin
        @exception_raised.each{|hook| hook.call(e, env) }
      rescue => hook_e
        e = hook_e
      end

      twerr = Twirp::Error.internal_with(e)
      resp_body = JSON.generate(twerr.to_h)
      [500, error_response_headers, [resp_body]]
    end

    def error_response_headers
      {'Content-Type' => 'application/json'}
    end

  end
end
