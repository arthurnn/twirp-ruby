require 'rack'
require_relative 'gen/haberdasher_pb.rb'
require_relative 'gen/haberdasher_twirp.rb'

client = Example::HaberdasherProtoClient.new("http://localhost:8080")
puts client.rpc(:HelloWorld, {:name => "World"}).inspect
