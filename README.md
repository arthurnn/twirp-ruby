# Twirp-Ruby

[![Run Tests](https://github.com/github/twirp-ruby/actions/workflows/tests.yml/badge.svg)](https://github.com/github/twirp-ruby/actions/workflows/tests.yml)

[Twirp is a protocol](https://github.github.io/twirp/docs/spec_v5.html) for routing and serialization of services defined in a [.proto file](https://developers.google.com/protocol-buffers/docs/proto3), allowing easy implementation of RPC services with auto-generated clients in different languages.

The [canonical implementation](https://github.com/github/twirp) is in Golang. The Twirp-Ruby project is the official implementation in Ruby for both server and clients.


## Install

Add `gem "twirp"` to your Gemfile, or install with `gem install twirp`.

To auto-generate Ruby code from a proto file, use the `protoc` plugin and the `--ruby_out` option ([see Wiki page](https://github.com/github/twirp-ruby/wiki/Code-Generation)).


## Documentation

[On the wiki](https://github.com/github/twirp-ruby/wiki).


## Contributing

[On the CONTRIBUTING file](CONTRIBUTING.md).

### Version 1 to 2

The upgrade should be mostly compatible.
The biggest change is that version 2 now allows Faraday 2.x as the http client.

For more information on the changes, see [changeset](https://github.com/github/twirp-ruby/compare/v1.9.0...v2.0.0).

