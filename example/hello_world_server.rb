require 'rack'
require 'webrick'
require 'logger'

require_relative 'hello_world/service_twirp.rb'

# Service implementation
class HelloWorldHandler
  def hello(req, env)
    puts ">> Hello #{req.name}"
    {message: "Hello #{req.name}"}
  end
end

# Instantiate Service
handler = HelloWorldHandler.new()
service = Example::HelloWorld::HelloWorldService.new(handler)


# Mount on webserver
path_prefix = "/twirp/" + service.full_name
server = WEBrick::HTTPServer.new(Port: 8000)
server.mount path_prefix, Rack::Handler::WEBrick, service
Twirp.logger = Logger.new(STDOUT)
server.start
