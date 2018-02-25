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

### HelloWorld Example

See the `example/` folder for the final product.

First create a basic `.proto` file:

```protobuf
syntax = "proto3";
package example;

service HelloWorld {
    rpc Hello(HelloRequest) returns (HelloResponse);
}

message HelloRequest {
    string name = 1;
}

message HelloResponse {
    string message = 1;
}
```

Run the `protoc` binary to auto-generate `helloworld_pb.rb` and `haberdasher_twirp.rb` files:

```sh
➜ protoc --proto_path=. ./haberdasher.proto --ruby_out=gen --twirp_ruby_out=gen
```

Write a handler for the auto-generated service, this is your implementation:

```ruby
class HellowWorldHandler
  def hello(input, env)
    {message: "Hello #{input.name}"}
  end
end
```

Initialize the service with your handler and mount it as a Rack app:

```ruby
require 'rack'
require_relative 'gen/haberdasher_pb.rb'
require_relative 'gen/haberdasher_twirp.rb'

handler = HellowWorldHandler.new()
service = Example::HelloWorld.new(handler)
Rack::Handler::WEBrick.run service
```

You can also mount onto a rails app:

```ruby
App::Application.routes.draw do
  mount service, at: service.full_name
end
```

Twirp services accept both Protobuf and JSON messages. It is easy to `curl` your service to get a response:

```sh
curl --request POST \
  --url http://localhost:8080/twirp/example.HelloWorld/Hello \
  --header 'content-type: application/json' \
  --data '{"name":"World"}'
```
