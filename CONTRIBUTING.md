# Contribute to Twirp-Ruby

## Issues and Pull Requests

Features and bugfixes are managed through [GitHub's Issues and Pull Requests](https://github.com/arthurnn/twirp-ruby/issues). Contributions are welcome and once approved, they are merged into master.

## Run tests and example code

* Install gems: `bundle install`
* Run Ruby tests: `rake`
* Run Go tests (test code generation): `go test ./protoc-gen-twirp_ruby/... ./internal/gen/typemap/...`
* Run example code (see [example/README.md](example/README.md)).

## Release Process

The Ruby and Go components now have separate release processes. They are no longer coupled in terms of versioning.

* Ruby library follows [Semantic Versioning (SemVer)](https://semver.org/), using tags like `ruby-v1.13.0`
* Go library follows [Go module versioning conventions](https://go.dev/doc/modules/version-numbers)

Both components can be released using GitHub Actions workflows.

### Ruby Release Process

1. Update the version in [`lib/twirp/version.rb`](lib/twirp/version.rb) following semantic versioning.
2. Commit and push these changes to the main branch:

   ```bash
   git commit -am "Bump Ruby version to vX.Y.Z"
   git push origin main
   ```

3. Go to the Actions tab in the GitHub repository and select the "Ruby Release" workflow.
4. Click "Run workflow" and provide:
   * Version: The version number without the 'v' prefix (e.g., "1.13.0")
   * Confirm: Type "yes" to confirm
5. Click "Run workflow" to start the release process.

The workflow will:

* Run all Ruby tests
* Create a Git tag with format `ruby-vX.Y.Z`
* Create a GitHub Release

6. Run `bundle exec rake release` locally to push the gem

7. Verify the gem is available at [https://rubygems.org/gems/twirp](https://rubygems.org/gems/twirp)

### Go Release Process

1. Update the version in [`protoc-gen-twirp_ruby/version.go`](protoc-gen-twirp_ruby/version.go) following semantic versioning.
2. Commit and push these changes to the main branch:

   ```bash
   git commit -am "Bump Go version to vX.Y.Z"
   git push origin main
   ```

3. Go to the Actions tab in the GitHub repository and select the "Go Release" workflow.
4. Click "Run workflow" and provide:
   * Version: The version number without the 'v' prefix (e.g., "1.13.0")
   * Confirm: Type "yes" to confirm
5. Click "Run workflow" to start the release process.

The workflow will:

* Run all Go tests
* Create Git tags with formats `go-vX.Y.Z` and `vX.Y.Z` (for Go modules compatibility)
* Create a GitHub Release

6. Verify the release is visible on the [GitHub Releases page](https://github.com/arthurnn/twirp-ruby/releases)


## General Notes

* The two components can be released independently according to their own development schedules
* Always test both Ruby and Go components before releasing either one
* Update the [`RELEASE_NOTES.md`](RELEASE_NOTES.md) file with significant changes for both Ruby and Go releases
* The GitHub workflows automate most of the release process but still require manual version updates
