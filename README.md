# Twirp-Ruby

[Twirp is a protocol](https://twitchtv.github.io/twirp/docs/spec_v5.html) for routing and serialization of services defined in a [.proto file](https://developers.google.com/protocol-buffers/docs/proto3), allowing easy implementation of RPC services with auto-generated clients in different languages.

The [cannonical implementation](https://github.com/twitchtv/twirp) is in Golang. The Twirp-Ruby project in this repository is the Ruby implementation.


## Install

Add `gem "twirp"` to your Gemfile, or install with `gem install twirp`.

## Features

 * Given a `.proto` file, generate Twirp services and clients in Ruby.
 * Implement RPC methods in a plain object called Service Handler.
 * Mount the service as a Rack app.
 * Service hooks for integrations and monitoring.
 * Generated clients.

## Documentation

[Refer to the Wiki](https://github.com/twitchtv/twirp-ruby/wiki).
