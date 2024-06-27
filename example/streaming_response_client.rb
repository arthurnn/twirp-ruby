require 'rack'

require_relative 'streaming_response/service_twirp.rb'

# Assume streaming server is running locally
c = Example::StreamingResponse::HelloWorldStreamingClient.new("http://localhost:9292/twirp")

resp = c.hello(name: "xxx") do |msg|
  puts "Received: #{msg}"
end


if resp.error
  puts resp.error
else
  puts "Full response:"
  puts resp.data
end
