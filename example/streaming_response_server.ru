require_relative 'streaming_response/service_twirp.rb'

class SlowStreamer
  def initialize(req)
    @req = req
  end

  def each
    (1..5).each do |i|
      puts "SlowStreamer: each #{i}"
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
handler = HelloWorldStreamingHandler.new
service = Example::StreamingResponse::HelloWorldStreamingService.new(handler)

run service
