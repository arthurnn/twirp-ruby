require 'json'

module Twirp

  module Encoding
    JSON = "application/json"
    PROTO = "application/protobuf"

    class << self

      def decode(bytes, msg_class, content_type)
        case content_type
        when JSON  then msg_class.decode_json(bytes)
        when PROTO then msg_class.decode(bytes)
        else raise ArgumentError.new("Invalid content_type")
        end
      end

      def encode(msg_obj, msg_class, content_type)
        case content_type
        when JSON  then msg_class.encode_json(msg_obj)
        when PROTO then msg_class.encode(msg_obj)
        else raise ArgumentError.new("Invalid content_type")
        end
      end

      def encode_json(attrs)
        ::JSON.generate(attrs)
      end

      def decode_json(bytes)
        ::JSON.parse(bytes)
      end

      def valid_content_type?(content_type)
        content_type == JSON || content_type == PROTO
      end

      def valid_content_types
        [JSON, PROTO]
      end

    end
  end

end
