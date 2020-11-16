# Twirp HelloWorld Example

### Run the example

To run the example, first make sure you are in the /example folder:
```sh
cd example
```

Install gems:
```sh
gem install bundler
bundle install
```

Start the hello_world server:
```sh
bundle exec ruby hello_world_server.rb
```

Now you can send `curl` requests from another terminal window:
```sh
curl --request POST \
  --url http://localhost:8080/twirp/example.hello_world.HelloWorld/Hello \
  --header 'Content-Type: application/json; strict=true' \
  --data '{"name": "World"}'
```

To send requests from Ruby code, run the hello_world client example:
```sh
bundle exec ruby hello_world_client.rb
```

### Run code generation

Try to add a new field in `./hello_world/service.proto`, then run the generator code and see if the new field was properly added in the generated files.

Make sure you have the [protobuf compiler](https://github.com/golang/protobuf) (version 3+).

Install the twirp plugin with go:
```sh
go get -u github.com/twitchtv/twirp-ruby/protoc-gen-twirp_ruby
```

From the `/example` folder, run the generator command:
```sh
protoc --proto_path=. ./hello_world/service.proto --ruby_out=. --twirp_ruby_out=.
```
