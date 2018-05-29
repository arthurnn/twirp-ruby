# Twirp-Ruby

[Twirp is a protocol](https://twitchtv.github.io/twirp/docs/spec_v5.html) for routing and serialization of services defined in a [.proto file](https://developers.google.com/protocol-buffers/docs/proto3), allowing easy implementation of RPC services with auto-generated clients in different languages.

The [cannonical implementation](https://github.com/twitchtv/twirp) is in Golang. The Twirp-Ruby project in this repository is the Ruby implementation.


## Install

Add `gem "twirp"` to your Gemfile, or install with `gem install twirp`.


## Documentation

[Refer to the Wiki](https://github.com/twitchtv/twirp-ruby/wiki).


## Usage Example

Define the service and client using the DSL. This can be [auto-generated from a .proto file](https://github.com/twitchtv/twirp-ruby/wiki/Code-Generation).

```ruby
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


Implement each rpc method with a [Service Handler](https://github.com/twitchtv/twirp-ruby/wiki/Service-Handlers). For example:

```ruby
class HelloWorldHandler

  def hello(req, env)
    if req.name.empty?
      return Twirp::Error.invalid_argument("name is mandatory")
    end

    {message: "Hello #{req.name}"}
  end

end
```

Service Handlers are just plain objects that respond to rpc methods with already serialized requests. Because of this they are [very easy to test](https://github.com/twitchtv/twirp-ruby/wiki/Unit-Tests). Integration with Rack middleware can be done through [service hooks](https://github.com/twitchtv/twirp-ruby/wiki/Service-Hooks), keeping the handler free of dependencies.

Start the service in localhost:


```ruby
require 'rack'

handler = HelloWorldHandler.new()
service = Example::HelloWorldService.new(handler)

path_prefix = "/twirp/" + service.full_name
server = WEBrick::HTTPServer.new(Port: 3000)
server.mount path_prefix, Rack::Handler::WEBrick, service
server.start
```

Talk to your service using Protobuf from the [client](https://github.com/twitchtv/twirp-ruby/wiki/Twirp-Clients):

```ruby
client = Example::HelloWorldClient.new("http://localhost:3000/twirp")
resp = client.hello(name: "World")
if resp.error
  puts resp.error # <Twirp::Error code:... msg:"..." meta:{...}>
else
  puts resp.data  # <Example::HelloResponse: message:"Hello World">
end
```

Or debug using JSON from `curl`:

```sh
curl --request POST \
  --url http://localhost:3000/twirp/example.HelloWorld/Hello \
  --header 'Content-Type: application/json' \
  --data '{"name": "World"}'
```

You can also auto-generate clients in other languages like Golang, JavaScript, Python, Rust, etc. (see [Twirp Golang for more info](https://github.com/twitchtv/twirp)).
