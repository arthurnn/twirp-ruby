require 'rack'
require_relative 'gen/haberdasher_pb.rb'
require_relative 'gen/haberdasher_twirp.rb'

class HaberdasherHandler
    def hello_world(req)
        return Example::HelloWorldResponse.new(message: "Hello #{req.name}")
    end
end

handler = HaberdasherHandler.new()
Rack::Handler::WEBrick.run Example::HaberdasherService.new(handler)
