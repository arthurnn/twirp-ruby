require 'rack'
require 'webrick'

require_relative 'streaming_response/service_twirp.rb'

class SlowStreamer
  def initialize(req)
    @req = req
  end

  def each
    (1..5).each do |i|
      puts "each #{i}"
      yield({ message: "Hello #{@req.name} #{i}" })
      sleep 1
    end
  end
end

# Service implementation
class HelloWorldStreamingHandler
  def hello(req, env)
    puts ">> Hello #{req.name}"
    SlowStreamer.new(req)
  end
end

# Instantiate Service
handler = HelloWorldStreamingHandler.new()
service = Example::StreamingResponse::HelloWorldStreamingService.new(handler)

class DummyStreamer
  def each
    (1..5).each do |i|
      puts "each #{i}"
      yield("Hello #{i}")
      sleep 1
    end
  end
end

class Dummy
  def call(rack_env)
    [200, {}, DummyStreamer.new]
  end
end

# Mount on webserver
# path_prefix = "/twirp/" + service.full_name
# run Dummy.new
