# Twirp-Ruby

[![Run Tests](https://github.com/github/twirp-ruby/actions/workflows/tests.yml/badge.svg)](https://github.com/github/twirp-ruby/actions/workflows/tests.yml)

[Twirp is a protocol](https://github.github.io/twirp/docs/spec_v5.html) for routing and serialization of services defined in a [.proto file](https://developers.google.com/protocol-buffers/docs/proto3), allowing easy implementation of RPC services with auto-generated clients in different languages.

The [canonical implementation](https://github.com/twitchtv/twirp) is in Golang. The Twirp-Ruby project is the official implementation in Ruby for both server and clients.


## Install

Add `gem "twirp"` to your Gemfile, or install with `gem install twirp`.

To auto-generate Ruby code from a proto file, use the `protoc` plugin and the `--ruby_out` option ([see Wiki page](https://github.com/github/twirp-ruby/wiki/Code-Generation)).


## Documentation

[On the wiki](https://github.com/github/twirp-ruby/wiki).


## Contributing

[On the CONTRIBUTING file](CONTRIBUTING.md).

## Releases and changes

See the [releases](https://github.com/github/twirp-ruby/releases) page for latest information about released versions.
