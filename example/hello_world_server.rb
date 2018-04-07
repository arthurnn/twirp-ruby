require 'rack'
require_relative 'hello_world/service_pb.rb'
require_relative 'hello_world/service_twirp.rb'

class HelloWorldHandler
  def hello(req, env)
    puts ">> Hello #{req.name}"
    {message: "Hello #{req.name}"}
  end
end

handler = HelloWorldHandler.new()
service = Example::HelloWorldService.new(handler)

Rack::Handler::WEBrick.run service
