# Copyright 2018 Twitch Interactive, Inc.  All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not
# use this file except in compliance with the License. A copy of the License is
# located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

require_relative 'encoding'
require_relative 'error'
require_relative 'service_dsl'
require 'rack/request'

module Twirp

  class Service

    # DSL to define a service with package, service and rpcs.
    extend ServiceDSL

    class << self

      # Whether to raise exceptions instead of handling them with exception_raised hooks.
      # Useful during tests to easily debug and catch unexpected exceptions.
      attr_accessor :raise_exceptions # Default: false

      # Rack response with a Twirp::Error
      def error_response(twerr)
        status = Twirp::ERROR_CODES_TO_HTTP_STATUS[twerr.code]
        headers = {'Content-Type' => Encoding::JSON} # Twirp errors are always JSON, even if the request was protobuf
        resp_body = Encoding.encode_json(twerr.to_h)
        [status, headers, [resp_body]]
      end

    end

    def initialize(handler)
      @handler = handler

      @before = []
      @on_success = []
      @on_error = []
      @exception_raised = []
    end

    # Setup hook blocks.
    def before(&block) @before << block; end
    def on_success(&block) @on_success << block; end
    def on_error(&block) @on_error << block; end
    def exception_raised(&block) @exception_raised << block; end

    # Service full_name is needed to route http requests to this service.
    def full_name; @full_name ||= self.class.service_full_name; end
    def name; @name ||= self.class.service_name; end

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

    # Call the handler method with input attributes or protobuf object.
    # Returns a proto object (response) or a Twirp::Error.
    # Hooks are not called and exceptions are raised instead of being wrapped.
    # This is useful for unit testing the handler. The env should include
    # fake data that is used by the handler, replicating middleware and before hooks.
    def call_rpc(rpc_method, input={}, env={})
      base_env = self.class.rpcs[rpc_method.to_s]
      return Twirp::Error.bad_route("Invalid rpc method #{rpc_method.to_s.inspect}") unless base_env

      env = env.merge(base_env)
      input = env[:input_class].new(input) if input.is_a? Hash
      env[:input] = input
      env[:content_type] ||= Encoding::PROTO
      env[:http_response_headers] = {}
      call_handler(env)
    end


  private

    # Parse request and fill env with rpc data.
    # Returns a bad_route error if could not be properly routed to a Twirp method.
    # Returns a malformed error if could not decode the body (either bad JSON or bad Protobuf)
    def route_request(rack_env, env)
      rack_request = Rack::Request.new(rack_env)

      if rack_request.request_method != "POST"
        return route_err(:bad_route, "HTTP request method must be POST", rack_request)
      end

      content_type = rack_request.get_header("CONTENT_TYPE")
      if !Encoding.valid_content_type?(content_type)
        return route_err(:bad_route, "Unexpected Content-Type: #{content_type.inspect}. Content-Type header must be one of #{Encoding.valid_content_types.inspect}", rack_request)
      end
      env[:content_type] = content_type

      path_parts = rack_request.path.split("/")
      if path_parts.size < 3 || path_parts[-2] != self.full_name
        return route_err(:bad_route, "Invalid route. Expected format: POST {BaseURL}/#{self.full_name}/{Method}", rack_request)
      end
      method_name = path_parts[-1]

      base_env = self.class.rpcs[method_name]
      if !base_env
        return route_err(:bad_route, "Invalid rpc method #{method_name.inspect}", rack_request)
      end
      env.merge!(base_env) # :rpc_method, :input_class, :output_class

      input = nil
      begin
        body_str = rack_request.body.read
        rack_request.body.rewind # allow other middleware to read again (https://github.com/github/twirp-ruby/issues/50)
        input = Encoding.decode(body_str, env[:input_class], content_type)
      rescue => e
        error_msg = "Invalid request body for rpc method #{method_name.inspect} with Content-Type=#{content_type}"
        if e.is_a?(Google::Protobuf::ParseError)
          error_msg += ": #{e.message.strip}"
        end
        return route_err(:malformed, error_msg, rack_request)
      end

      env[:input] = input
      env[:http_response_headers] = {}
      return
    end

    def route_err(code, msg, req)
      Twirp::Error.new code, msg, twirp_invalid_route: "#{req.request_method} #{req.path}"
    end


    # Call handler method and return a Protobuf Message or a Twirp::Error.
    def call_handler(env)
      m = env[:ruby_method]
      if !@handler.respond_to?(m)
        return Twirp::Error.unimplemented("Handler method #{m} is not implemented.")
      end

      out = @handler.send(m, env[:input], env)
      case out
      when env[:output_class], Twirp::Error
        out
      when Hash
        env[:output_class].new(out)
      else
        Twirp::Error.internal("Handler method #{m} expected to return one of #{env[:output_class].name}, Hash or Twirp::Error, but returned #{out.class.name}.")
      end
    end

    def success_response(output, env)
      begin
        env[:output] = output
        @on_success.each{|hook| hook.call(env) }

        headers = env[:http_response_headers].merge('Content-Type' => env[:content_type])
        resp_body = Encoding.encode(output, env[:output_class], env[:content_type])
        [200, headers, [resp_body]]

      rescue => e
        return exception_response(e, env)
      end
    end

    def error_response(twerr, env)
      begin
        @on_error.each{|hook| hook.call(twerr, env) }
        self.class.error_response(twerr)
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
      self.class.error_response(twerr)
    end

  end
end
