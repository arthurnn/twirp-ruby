# Twirp-Ruby

[Twirp is a protocol](https://twitchtv.github.io/twirp/docs/spec_v5.html) for routing and serialization of services defined in a [.proto file](https://developers.google.com/protocol-buffers/docs/proto3), allowing easy implementation of RPC services with auto-generated clients in different languages.

The [cannonical implementation](https://github.com/twitchtv/twirp) is in Golang. The Twirp-Ruby project in this repository is the Ruby implementation.


## Install

Add `gem "twirp"` to your Gemfile, or install with `gem install twirp`.


## Documentation

[Refer to the Wiki](https://github.com/twitchtv/twirp-ruby/wiki).


## Example

Starting with a [.proto file](https://developers.google.com/protocol-buffers/docs/proto3):

```protobuf
syntax = "proto3";

package twirp.example.haberdasher;
option go_package = "haberdasher";

// Haberdasher service makes hats for clients.
service Haberdasher {
  // MakeHat produces a hat of mysterious, randomly-selected color
  rpc MakeHat(Size) returns (Hat);
}

message Size {
  int32 inches = 1; // must be > 0
}

message Hat {
  int32 inches = 1;
  string color = 2; // anything but "invisible"
  string name = 3; // i.e. "bowler"
}
```

Your Service Handler implementation:

```ruby
class HaberdasherHandler
  def make_hat(size, env)
    if size.inches <= 0
      return Twirp::Error.invalid_argument("I can't make a hat that small!")
    end

    {
      inches: size.inches,
      color: ["white", "black", "brown", "red", "blue"].sample,
      name: ["bowler", "baseball cap", "top hat", "derby"].sample,
    }
  end
end
```

Mount your service in a Rack app, then talk to it using the generated client:

```ruby
client = Twirp::Example::Haberdasher::HaberdasherClient.new("http://localhost:8080")

resp = client.make_hat(inches: 12)
if resp.error != nil {
  puts "oh no: #{resp.error.msg}"
else
  hat = resp.data
  puts "I have a nice new hat: #{hat}"
end
```

