require_relative "streaming_response_server"

# TODO: Make this example better (rename file).

handler = HelloWorldStreamingHandler.new()
service = Example::StreamingResponse::HelloWorldStreamingService.new(handler)

run service
