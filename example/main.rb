require 'rack'
require_relative 'gen/haberdasher_pb.rb'
require_relative 'gen/haberdasher_twirp.rb'

class HaberdasherHandler
    def hello_world(req)
        return Example::HelloWorldResponse.new(message: "Hello #{req.name}")
    end
end

svc = HaberdasherHandler.new()
Rack::Handler::WEBrick.run Proc.new {|env| Example::HaberdasherService.new(svc).call(env)}
