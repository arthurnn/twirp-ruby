require 'rack'
require 'rackup'

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
Rackup::Server.start app: service, Port: 8080
