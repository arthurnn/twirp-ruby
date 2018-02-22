module Twirp

  class Environment

    def initialize(rack_request)
      @rack_request = rack_request
      @response_http_headers = {}
      @data = {}
    end

    def [](key)
      @data[key]
    end

    def []=(key, value)
      @data[key] = value
    end

    def to_hash
      @data
    end

    def to_h
      to_hash
    end

    def get_http_request_header(header)
      @rack_request.get_header(header)
    end

    def set_http_response_header(header, value)
      @response_http_headers[header] = value
    end

    # Accessing the raw Rack::Request is convenient, but it is
    # discouraged because it adds extra dependencies to your handler.
    # Instead of directly accessing the rack_request, it is better to
    # add a before hook in the service that reads data from the Rack environment
    # and adds it to the Twirp environment, so all dependencies are clear. Example:
    #    svc.before do |rpc, input, env|
    #      env[:user] = env.rack_request.env['warden'].user
    #    end
    #
    def rack_request
      @rack_request
    end

  end
end
