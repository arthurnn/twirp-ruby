# Twirp-Ruby: Release notes

## Important: Separate Release Cycles

**Since v1.10.0, Go and Ruby components have different release cycles and version numbers.**

Releases are tagged in git with the `ruby-` and `go-` prefixes. To follow [Go module versioning conventions](https://go.dev/doc/modules/version-numbers) the Go releases are also tagged as `vX.Y.Z`.

## Go

### 1.14.0

- Update `google.golang.org/protobuf`(v1.36.6) and drop `github.com/golang/protobuf` dependency [#131](https://github.com/arthurnn/twirp-ruby/pull/131)

Full Changelog: https://github.com/arthurnn/twirp-ruby/compare/v1.13.0...go-v1.14.0

### 1.13.0 & 1.12.0 & 1.11.0

No changes to go files:
https://github.com/arthurnn/twirp-ruby/compare/v1.10.0...v1.13.0

## Ruby

### 1.13.1

https://github.com/arthurnn/twirp-ruby/compare/v1.13.0...ruby-v1.31.1

No ruby runtime changes, only ajusting docs.

### 1.13.0

https://github.com/arthurnn/twirp-ruby/compare/v1.12.0...v1.13.0

- [Rack 3.0 support](https://github.com/arthurnn/twirp-ruby/pull/124)
- [Better handle nil response status in client](https://github.com/arthurnn/twirp-ruby/pull/127)

### 1.12.0

https://github.com/arthurnn/twirp-ruby/compare/v1.10.0...v1.12.0

- [Expose response HTTP headers to the caller](https://github.com/arthurnn/twirp-ruby/pull/119)
- [Allow google-protobuf v4](https://github.com/arthurnn/twirp-ruby/pull/122)
- Lock Rack version to be < 3, until we fix Rack 3 compatibility

### 1.11.0 - not released

No ruby release for this version, despite an existent tag.
https://github.com/arthurnn/twirp-ruby/compare/v1.10.0...v1.11.0

There was no ruby change for this version therefor not release, instead that mark the de-coupling of the Go toolchain with the ruby version.
