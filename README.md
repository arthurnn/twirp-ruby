# Ruby Twirp

Twirp services and clients in Ruby.

### Installation
Install the `twirp` gem:
```sh
➜ gem install twirp
```

Use `go get` to install the ruby_twirp protoc plugin:
```sh
➜ go get github.com/cyrusaf/ruby-twirp/protoc-gen-twirp_ruby
```

You will also need:
 - [protoc](https://github.com/golang/protobuf), the protobuf compiler. You need
   version 3+.

### Haberdasher Example
See the `example/` folder for the final product.

First create a basic `.proto` file:
```protobuf
// haberdasher.proto
syntax = "proto3";
package example;

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
```sh
➜ protoc --proto_path=. ./haberdasher.proto --ruby_out=gen --twirp_ruby_out=gen
```

Write an implementation of our haberdasher service and attach to a rack server:
```ruby
# main.rb
require 'rack'
require_relative 'gen/haberdasher_pb.rb'
require_relative 'gen/haberdasher_twirp.rb'

class HaberdasherHandler
    def hello_world(req)
        return Example::HelloWorldResponse.new(message: "Hello #{req.name}")
    end
end

svc = HaberdasherHandler.new()
Rack::Handler::WEBrick.run Proc.new {|env| Example::HaberdasherService.new(svc).call(env)}
```

You can also mount onto a rails service:
```ruby
App::Application.routes.draw do
  svc = HaberdasherImplementation.new()
  mount Proc.new {|env| Example::HaberdasherService.new(svc).call(env)}, at: HaberdasherService::PATH_PREFIX
end
```

Run `ruby main.rb` to start the server on port 8080:
```sh
➜ ruby main.rb
```

`curl` your server to get a response:
```sh
➜ curl --request POST \
  --url http://localhost:8080/twirp/examples.Haberdasher/HelloWorld \
  --header 'content-type: application/json' \
  --data '{
	"name": "World"
}'
```
