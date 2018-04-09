# Twirp

Twirp allows to easily define RPC services and clients that communicate using Protobuf or JSON over HTTP.

This is the Ruby implementation, but Twirp is available in many other languages. The cannonical implementation is in Go: https://github.com/twitchtv/twirp

## Install

Add `gem "twirp"` to your Gemfile, or install with `gem install twirp`.

## Service DSL

Protobuf messages are defined with [google-protobuf](https://github.com/google/protobuf/tree/master/ruby), which has its own DSL to define message classes that can serialize into both Protobuf and JSON.

A Twirp service adds the RPC methods to send and receive those messages. For example:

```ruby
require 'twirp'

module Example
  class HelloWorldService < Twirp::Service
    package "example"
    service "HelloWorld"
    rpc :Hello, HelloRequest, HelloResponse, :ruby_method => :hello
  end

  class HelloWorldClient < Twirp::Client
    client_for HelloWorldService
  end
end
```


## Code Generation

RPC messages and the service definition can be auto-generated form a `.proto` file.

Code generation works with [protoc](https://github.com/golang/protobuf) (the protobuf compiler)
using the `--ruby_out` option to generate messages and `--twirp_ruby_out` to generate services and clients.

Make sure to install `protoc` (version 3+). Then use `go get` (Golang) to install the ruby_twirp protoc plugin:

```sh
go get -u github.com/cyrusaf/ruby-twirp/protoc-gen-twirp_ruby
```

Given a [Protobuf](https://developers.google.com/protocol-buffers/docs/proto3) file like [example/hello_world/service.proto](example/hello_world/service.proto), you can auto-generate proto and twirp files with the command:

```sh
protoc --proto_path=. --ruby_out=. --twirp_ruby_out=. ./example/hello_world/service.proto
```


## Twirp Service

A Twirp service is instantiated with a service handler to implement each rpc method.

An example handler for HelloWorld service would look like this:

```ruby
class HelloWorldHandler

  def hello(input, env)
    if input.name.empty?
      Twirp::Error.invalid_argument("name is mandatory")
    else
      {message: "Hello #{input.name}"}
    end
  end

end
```

The `intput` argument is the request message, and the returned value is expected to be the response message, or a `Twirp::Error`.

The `env` argument contains metadata related to the request, and other fields that could have been set from before
hooks (e.g. `env[:user_id]` from authentication).

### Unit Tests

Twirp already takes care of HTTP routing and serialization, you don't really need to fake HTTP requests in your tests. The Twirp service has the method
`.call_rpc(rpc_method, attrs={}, env={})` to call the handler with a fake Twirp env and making sure that the handler output is valid.

```ruby
require 'minitest/autorun'

class HelloWorldHandlerTest < Minitest::Test

  def test_hello_responds_with_name
    out = service.call_rpc :Hello, name: "World"
    assert_equal "Hello World", out.message
  end

  def test_hello_name_is_mandatory
    twerr = service.call_rpc :Hello, name: ""
    assert_equal :invalid_argument, twerr.code
  end

  def service
    handler = HelloWorldHandler.new()
    Example::HelloWorld.new(handler)
  end
end
```


### Start the Service

The service is a [Rack app](https://rack.github.io/) instantiated with your handler impementation. For example:

```ruby
require 'rack'

handler = HelloWorldHandler.new() # your handler implementation
service = Example::HelloWorldService.new(handler)

Rack::Handler::WEBrick.run service
```

Rack apps can also be mounted as Rails routes (e.g. `mount service, at: service.full_name`) and are compatible with many other frameworks.


## Twirp Clients

Generated clients implement the methods defined in the proto file. The response object contains `data` with an instance of the response class if successfull, or an `error` with an instance of `Twirp::Error` if there was a problem. For example, with the HelloWorld generated client:

```ruby
c = Example::HelloWorldClient.new("http://localhost:3000")
resp = c.hello(name: "World")
if resp.error
  puts resp.error #=> <Twirp::Error code:... msg:"..." meta:{...}>
else
  puts resp.data #=> <Example::HelloResponse: message:"Hello World">
end
```

### Configure Clients with Faraday

A Twirp client takes care of routing, serialization and error handling.

Other advanced HTTP options can be configured with [Faraday](https://github.com/lostisland/faraday) middleware. For example:

```ruby
c = MyClient.new(Faraday.new(:url => 'http://localhost:3000') do |c|
  c.use Faraday::Request::Retry # configure retries
  c.use Faraday::Request::BasicAuthentication, 'login', 'pass'
  c.use Faraday::Response::Logger # log to STDOUT
  c.use Faraday::Adapter::NetHttp # multiple adapters for different HTTP libraries
end)
```

## Server Hooks

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

