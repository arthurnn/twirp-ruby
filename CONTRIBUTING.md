# Contribute to Twirp-Ruby

## Issues and Pull Requests

Features and bugfixes are managed through Github's Issues and Pull Requests. Contributions are welcome and once approved, they are merged into master.

## Run tests and example code

 * Install gems: `bundle install`
 * Run Ruby tests: `rake`
 * Run Go tests (test code generation): `cd protoc-gen-twirp_ruby` then `go test ./...`
 * Run example code (see [example/README.md](example/README.md)).

## Make a new release (authors only)

Once enough new features are added, a new release is drafted.

 * Merge approved PRs into main.
 * Update VERSION with semantic versioning in:
   * `lib/twirp/version.rb` and
   * `protoc-gen-twirp_ruby/version.go`
 * Run `bundle install` to update the `Gemfile.lock` file with the new version.
 * Run `rake` to run tests.
 * Re-generate code (see [example/README.md](example/README.md)). Make sure to use the latest version of `protoc-gen-twirp_ruby`; if the repo is in `$GOPATH/src/github.com/arthurnn/twirp-ruby`, then you only need to do `go install github.com/arthurnn/twirp-ruby/protoc-gen-twirp_ruby` before running the `protoc` command to generate code. The generated code should be annotated with the new version.
 * Update example code and README if needed with new features.
 * Commit changes for the new version in main and push to remote.
 * [Draft a new release](https://github.com/arthurnn/twirp-ruby/releases) in Github. Create a new tag with the version. Add release notes (see previous releases to keep the same format).
 * Build and push the gem: `rake release`.
 * Update the Draft release with the created tag, and publish it.
