# Contribute to Twirp-Ruby

## Issues and Pull Requests

Features and bugfixes are managed through Github's Issues and Pull Requests. Contributions are welcome and once approved, they are merged into master.

## Run tests and example code

 * Install gems: `bundle install`
 * Run Ruby tests: `rake`
 * Run Go tests (test code generation): `cd protoc-gen-twirp_ruby` then `go test ./...`
 * Run example code (see [example/README.md](example/README.md)).

## Release Process

The Ruby and Go components now have separate release processes. They are no longer coupled in terms of versioning.

- Ruby library follows [Semantic Versioning (SemVer)](https://semver.org/), using git tags like `ruby-v1.13.0`. To find the releases go to [rubygems](https://rubygems.org/gems/twirp).
- Go library follows [Go module versioning conventions](https://go.dev/doc/modules/version-numbers). The releases are documented in the [releases](https://github.com/arthurnn/twirp-ruby/releases) page.

### Ruby Release Process

1. Update the version in `lib/twirp/version.rb` following semantic versioning.
2. Run `bundle install` to update the `Gemfile.lock` file with the new version.
3. Run all Ruby tests to ensure everything works:
   ```
   rake
   ```
4. Make sure examples are working and updated if needed:
   * Check examples in the `example/` and `example_rack2/` directories
   * Update any example code or documentation as needed
5. Commit changes and push to main branch:
   ```
   git commit -am "Bump Ruby version to vX.Y.Z"
   git push origin main
   ```
6. Build and publish the gem:
   ```
   rake release
   ```
   This will:
   * Create a git tag with the format `ruby-vX.Y.Z`
   * Build the gem
   * Push the gem to RubyGems.org (the canonical source for Ruby versions)
7. Verify the gem is available at https://rubygems.org/gems/twirp

### Go Release Process

1. Update the version in `protoc-gen-twirp_ruby/version.go`.
2. Run Go tests to ensure everything works:
   ```
   cd protoc-gen-twirp_ruby
   go test ./...
   cd ../internal/gen/typemap
   go test ./...
   ```
3. Regenerate any example code if needed.
4. Commit changes and push to main branch:
   ```
   git commit -am "Bump Go version to vX.Y.Z"
   git push origin main
   ```
5. Create a git tag for the Go release:
   ```
   git tag go-vX.Y.Z
   git push origin go-vX.Y.Z
   ```
6. Create a new release on GitHub:
   * Go to https://github.com/arthurnn/twirp-ruby/releases
   * Draft a new release using the tag `go-vX.Y.Z`
   * Add release notes detailing the changes in this version
   * Publish the release
7. The GitHub releases page is the canonical source for Go version releases.

## General Notes

* The two components can be released independently according to their own development schedules
* Always test both Ruby and Go components before releasing either one
* Update the RELEASE_NOTES.md file with significant changes for both Ruby and Go releases
