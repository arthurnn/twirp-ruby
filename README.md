# Twirp-Ruby

[![Run Tests](https://github.com/arthurnn/twirp-ruby/actions/workflows/tests.yml/badge.svg)](https://github.com/arthurnn/twirp-ruby/actions/workflows/tests.yml)

[Twirp is a protocol](https://twitchtv.github.io/twirp/docs/spec_v5.html) for routing and serialization of services defined in a [.proto file](https://developers.google.com/protocol-buffers/docs/proto3), allowing easy implementation of RPC services with auto-generated clients in different languages.

The [canonical implementation](https://github.com/twitchtv/twirp) is in Golang. The Twirp-Ruby project is the official implementation in Ruby for both server and clients.


## Install

Add `gem "twirp"` to your Gemfile, or install with `gem install twirp`.

To auto-generate Ruby code from a proto file, use the `protoc` plugin and the `--ruby_out` option ([see Wiki page](https://github.com/arthurnn/twirp-ruby/wiki/Code-Generation)).

### No backwards compatible breaking changes, between minor versions(1.10.0)

When upgrading from version 1.9.0 to 1.10.0, note that there is a breaking change in the `Twirp::ClientResp#initialize` method. The method now accepts keyword arguments. For more details, refer to this [comparison](https://github.com/arthurnn/twirp-ruby/compare/v1.9.0...v1.10.0#diff-b3c497150f4ae769df1a5d90e43142983cfd4d780392cbaa218d74912fa3a174) and this [issue](https://github.com/arthurnn/twirp-ruby/issues/99).

## Documentation

[On the wiki](https://github.com/arthurnn/twirp-ruby/wiki).

## Contributing

[On the CONTRIBUTING file](CONTRIBUTING.md).

## Releases and changes

See the [releases](https://github.com/arthurnn/twirp-ruby/releases) page for latest information about released versions.
