require 'rack'

require_relative 'hello_world/service_twirp.rb'

# Assume hello_world_server is running locally
c = Example::HelloWorld::HelloWorldClient.new("http://localhost:8080/twirp")

resp = c.hello(name: "World")
if resp.error
  puts resp.error
else
  puts resp.data.message
end
