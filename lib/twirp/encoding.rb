module Twirp

  module Encoding
    JSON = "application/json"
    PROTO = "application/protobuf"

    def self.decode(bytes, msg_class, content_type)
      case content_type
      when JSON  then msg_class.decode_json(bytes)
      when PROTO then msg_class.decode(bytes)
      else raise ArgumentError.new("Invalid content_type")
      end
    end

    def self.encode(msg_obj, msg_class, content_type)
      case content_type
      when JSON  then msg_class.encode_json(msg_obj)
      when PROTO then msg_class.encode(msg_obj)
      else raise ArgumentError.new("Invalid content_type")
      end
    end

    def self.valid_content_type?(content_type)
      content_type == Encoding::JSON || content_type == Encoding::PROTO
    end

    def self.valid_content_types
      [Encoding::JSON, Encoding::PROTO]
    end
  end

end
