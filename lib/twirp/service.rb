module Twirp
  class Service
    @@rpcs = {}

    def initialize(svc)
      @svc = svc
    end

    def self.rpc(name, request_class, response_class)
      @@rpcs[name] = {
        request_class: request_class,
        response_class: response_class
      }
    end

    def route_request(req)
      # Parse url to get method names
      method_name = req.path_info[1..-1]

      # Get req/res types from @@rpcs
      rpc = @@rpcs[method_name.to_sym]
      request_class = rpc[:request_class]
      response_class = rpc[:response_class]

      case req.env["CONTENT_TYPE"]
      when "application/json"
        return self.serve_json(req, method_name, request_class, response_class)
      when "application/protobuf"
        return self.serve_proto(req, method_name, request_class, response_class)
      else
        return self.serve_error(Twerr.NotFound("unexpected Content-Type: #{req.env["CONTENT_TYPE"]}"))
      end
    end

    def serve_json(req, method_name, request_class, response_class)
      params = request_class.decode_json(req.body.read)
      resp = @svc.send(method_name.underscore, params)
      self.serve_success_json(response_class.encode_json(resp))
    end

    def serve_proto(req, method_name, request_class, response_class)
      params = request_type.decode(req.body.read)
      resp = @svc.send(method_name.underscore, params)
      self.serve_success_proto(response_class.encode(resp))
    end

    def serve_success_proto(resp)
      return ['200', {'Content-Type' => 'application/protobuf'}, [resp]]
    end

    def serve_success_json(resp)
      return ['200', {'Content-Type' => 'application/json'}, [resp]]
    end

    def serve_error(twerr)
      return ['500', {'Content-Type' => 'application/json'}, []]
    end

    def handler
      return Proc.new do |env|
        req = Rack::Request.new(env)
        self.route_request(req)
      end
    end
  end
end
