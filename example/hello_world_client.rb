require 'rack'
require_relative 'hello_world/service_pb.rb'
require_relative 'hello_world/service_twirp.rb'

# Assume hello_world_server is running locally
c = Example::HelloWorldClient.new("http://localhost:8080")

resp = c.hello(name: "World")
if resp.error
  puts resp.error
else
  puts resp.data.message
end
