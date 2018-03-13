# Twirp

Ruby implementation for for [Twirp](https://github.com/twitchtv/twirp). It includes:
 
 * [twirp gem](https://rubygems.org/gems/twirp): with library code like `Twirp::Error` and `Twirp::Service`.
 * `protoc-gen-twirp_ruby` protoc plugin to generate Ruby services and clients from a Protobuf file. 


## Installation

Install the gem with `gem install twirp` or in Bundler `gem "twirp"`.

For code generation, Make sure that you have the [protobuf compiler](https://github.com/golang/protobuf) (install version 3+).
And then use `go get` to install the ruby_twirp protoc plugin:

```sh
➜ go get github.com/cyrusaf/ruby-twirp/protoc-gen-twirp_ruby
```


## Usage Example

Let's make a `HelloWorld` service in Twirp. Start with a [Protobuf](https://developers.google.com/protocol-buffers/docs/proto3) file:

```protobuf
// hello_world.proto

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

Congrats! You already have everything you need to make clients, message routing, serialization and also reasonable documentation for your service.


### Generate code

Run the `protoc` binary with the twirp_ruby plugin to auto-generate code:

```sh
➜ protoc --proto_path=. ./hello_world.proto --ruby_out=gen --twirp_ruby_out=gen
```

This will generate `gen/helloworld_pb.rb` and `gen/helloworld_twirp.rb` files with proto messages, service and client code.


#### Implement the Service Handler

Your Service Handler is a simple class that implements each method defined in the proto file.
For each method, the `intput` is an instance of the protobuf request message. The Twirp `env`
contains metadata related to the request, and other fields that could have been set from before
hooks (e.g. `env[:user_id]` from authentication).

```ruby
class HelloWorldHandler
  def hello(input, env)
    {message: "Hello #{input.name}"}
  end
end
```

### Mount the service to receive HTTP requests

The service is a Rack app:

```ruby
require 'rack'

handler = HelloWorldHandler.new() # your implementation
service = Example::HelloWorld.new(handler) # twirp-generated

Rack::Handler::WEBrick.run service
```

You can also mount onto a Rails route:

```ruby
App::Application.routes.draw do
  mount service, at: service.full_name
end
```

Start the server and `curl` with JSON to test if everything works:

```sh
➜ curl --request POST \
  --url http://localhost:8080/example.HelloWorld/Hello \
  --header 'Content-Type: application/json' \
  --data '{"name": "World"}'
```

### Unit Test the Service Handler

Twirp already takes care of HTTP routing and serialization, you don't really need to build fake HTTP requests in your tests.
Instead, you should focus on testing your Service Handler. For convenience, the Twirp Service has the method
`.call_rpc(rpc_method, attrs={}, env={})` to call the handler with a fake Twirp env and making sure that the handler output is valid.

```ruby
require 'minitest/autorun'
class HelloWorldHandlerTest < Minitest::Test

  def test_hello_responds_with_name
    service = Example::HelloWorld.new(HelloWorldHandler.new())
    out = service.call_rpc :Hello, name: "World"
    assert_equal "Hello World", out.message
  end
end
```


## Service Hooks

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

Hooks are setup in the service instance:

```ruby
svc = Example::HelloWorld.new(handler)

svc.before do |rack_env, env|
  # Runs if properly routed to an rpc method, but before calling the method handler.
  # This is the only place to read the Rack env to access http request and middleware data.
  # The Twirp env has the same routing info as in the handler method, e.g. :rpc_method, :input and :input_class.
  # Returning a Twirp::Error here cancels the request, and the error is returned instead.
  # If an exception is raised, the exception_raised hook will be called followed by on_error.
  env[:user_id] = authenticate(rack_env)
end

svc.on_success do |env|
  # Runs after the rpc method is handled, if it didn't return Twirp errors or raised exceptions.
  # The env[:output] contains the serialized message of class env[:ouput_class].
  # If an exception is raised, the exception_raised hook will be called.
  success_count += 1
end

svc.on_error do |twerr, env|
  # Runs on error responses, that is:
  #  * bad_route errors
  #  * before filters returning Twirp errors or raising exceptions.
  #  * hander methods returning Twirp errors or raising exceptions.
  # Raised exceptions are wrapped with Twirp::Error.internal_with(e).
  # If an exception is raised here, the exception_raised hook will be called.
  error_count += 1
end

svc.exception_raised do |e, env|
  # Runs if an exception was raised from the handler or any of the hooks.
  puts "[Error] #{e}\n#{e.backtrace.join("\n")}"
end
```


## Clients

TODO: clients and client code-generation are pending ...
