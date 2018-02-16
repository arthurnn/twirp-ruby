require 'rack'
require_relative 'gen/haberdasher_pb.rb'
require_relative 'gen/haberdasher_twirp.rb'

class HaberdasherHandler
    def hello_world(req)
        return {message: "Hello #{req.name}"}
    end
end

handler = HaberdasherHandler.new()
service = Example::HaberdasherService.new(handler)
Rack::Handler::WEBrick.run service
