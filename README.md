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
  --url http://localhost:8080/example.HelloWorld/Hello \
  --header 'content-type: application/json' \
  --data '{"name":"World"}'
```


## Hooks

In the lifecycle of a request, the Twirp service starts by routing the request to a valid
RPC method. If routing fails, the `on_error` hook is called with a bad_route error. 
If routing succeeds, the `before` hook is called before calling the RPC method handler, 
and then either `on_success` or `on_error` depending if the response is a Twirp error or not. 

```
routing -> before -> handler -> on_success
                             -> on_error
```

On every request, one and only one of `on_success` or `on_error` is called.


If exceptions are raised, the `exception_raised` hook is called. The exceptioni is wrapped with
an internal Twirp error, and if the `on_error` hook was not called yet, then it is called with
the wrapped exception.


```
routing -> before -> handler
                     ! exception_raised -> on_error
```

Example code with hooks:


```ruby
class HaberdasherHandler
  def make_hat(size, env)
    return {}
  end
end

handler = HaberdasherHandler.new
svc = Example::Haberdasher.new(handler)


svc.before do |rack_env, env|
  # Runs if properly routed to an rpc method, but before calling the method handler.
  # This is the only place to read the Rack Env to access http request and middleware data.
  # The Twirp env has the same routing info as in the handler method, e.g. :rpc_method, :input and :input_class.
  # If it returns a Twirp::Error, the handler is not called and this error is returned instead.
  # If an exception is raised, the exception_raised hook will be called and then on_error with the internal error.
end

svc.on_success do |env|
  # Runs after the rpc method is handled, if it didn't return Twirp errors or raised exceptions.
  # The env[:output] contains the serialized message of class env[:ouput_class]
  # Returned values are ignored (even if it returns Twirp::Error).
  # Exceptions should not happen here, but if an exception is raised the exception_raised hook will be
  # called, however on_error will not (either on_success or on_error are called once per request).
end

svc.on_error do |twerr, env|
  # Runs on error responses, that is:
  #  * routing errors (env does not have routing info here)
  #  * before filters returning Twirp errors or raising exceptions.
  #  * hander methods returning Twirp errors or raising exceptions.
  # Raised exceptions are wrapped with Twirp::Error.internal_with(e).
  # Returned values are ignored (even if it returns Twirp::Error).
  # Exceptions should not happen here, but if an exception is raised the exception_raised hook will be
  # called without calling on_error again later.
end

svc.exception_raised do |e, env|
  # Runs if an exception was raised from the handler or any of the hooks.
  environment = (ENV['APP_ENV'] || ENV['RACK_ENV'] || :development).to_sym
  case environment
    when :development raise e
    when :test
      puts "[Error] #{e}\n#{e.backtrace.join("\n")}"
  end
end
```
