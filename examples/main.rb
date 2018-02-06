require 'rack'
require_relative 'gen/haberdasher_pb.rb'
require_relative 'gen/haberdasher_twirp.rb'

class HaberdasherImplementation
    def HelloWorld(req)
        return Examples::HelloWorldResponse.new(message: "Hello #{req.name}")
    end
end

svc = HaberdasherImplementation.new()
Rack::Handler::WEBrick.run HaberdasherService.new(svc).handler
