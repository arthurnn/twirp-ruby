# Contribute to Twirp-Ruby

## Issues and Pull Requests

Features and bugfixes are managed through Github's Issues and Pull Requests. Contributions are welcome and once approved, they are merged into master.

## Run tests and example code

 * Install gems: `bundle install`
 * Run Ruby tests: `rake`
 * Run Go tests (test code generation): `cd protoc-gen-twirp_ruby` then `go test ./...`
 * Run example code (see `example/README.md`).

## Make a new release (for authors only)

Once enough new features are added, a new release is drafted.

 * Merge approved PRs into master.
 * Update VERSION in `lib/twirp/version.rb` and `protoc-gen-twirp_ruby/version.go`, following semantinc versioning.
 * Update the example code with new features (if needed), and re-generate code (see [example/README.md](example/README.md)). Make sure that you are using the latest version of `protoc-gen-twirp_ruby`, if the repo is in `$GOPATH/src/github.com/twitchtv/twirp-ruby`, then you only need to do `go install github.com/twitchtv/twirp-ruby/protoc-gen-twirp_ruby` before running the `protoc` command to generate code. The generated code should be annotated with the new version.
 * Run `bundle install` to update the `Gemfile.lock` file with the new version.
 * Run tests.
 * Commit changes for the new version in master and push to remote.
 * [Draft a new release](https://github.com/twitchtv/twirp-ruby/releases) in Github. Create a new tag with the version. Add release notes (see previous releases to keep the same format).
 * Build the gem: `gem build twirp.gemspec` and then push the new .gem file to Ruby Gems: `gem push twirp-X.X.X.gem`. You can delete the .gem file after that.
