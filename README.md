# Ruby Twirp

Twirp services and clients in Ruby.

### Installation
Install the `twirp` gem:
```
➜ gem install twirp
```

Use `go get` to install the ruby_twirp protoc plugin:
```
➜ go get github.com/cyrusaf/ruby-twirp/protoc-gen-twirp_ruby
```

You will also need:
 - [protoc](https://github.com/golang/protobuf), the protobuf compiler. You need
   version 3+.

### Haberdasher Example
See the `examples/` folder for the final product.

First create a basic `.proto` file:
```
// haberdasher.proto
syntax = "proto3";
package examples;

service Haberdasher {
    rpc HelloWorld(HelloWorldRequest) returns (HelloWorldResponse);
}

message HelloWorldRequest {
    string name = 1;
}

message HelloWorldResponse {
    string message = 1;
}

```

Run the `protoc` binary to generate `gen/haberdasher_pb.rb` and `gen/haberdasher_twirp.rb`.
```
➜ protoc --proto_path=. ./haberdasher.proto --ruby_out=gen --twirp_ruby_out=gen
```

Write an implementation of our haberdasher service and attach to a rack server:
```
# main.rb
require 'rack'
require_relative 'gen/haberdasher_pb.rb'
require_relative 'gen/haberdasher_twirp.rb'

class HaberdasherImplementation
    def HelloWorld(req)
        return Examples::HelloWorldResponse.new(message: "Hello #{req.name}")
    end
end

svc = HaberdasherImplementation.new()
url_map = Rack::URLMap.new HaberdasherService::PATH_PREFIX => HaberdasherService.new(svc).handler
Rack::Handler::WEBrick.run url_map
```

You can also mount onto a rails service:
```
App::Application.routes.draw do
  svc = HaberdasherImplementation.new()
  mount HaberdasherServer.new(svc).handler, at: HaberdasherServer::PATH_PREFIX
end
```

Run `ruby main.rb` to start the server on port 8080:
```
➜ ruby main.rb
```

`curl` your server to get a response:
```
➜ curl --request POST \
  --url http://localhost:8080/twirp/examples.Haberdasher/HelloWorld \
  --header 'content-type: application/json' \
  --data '{
	"name": "World"
}'
```
