require 'json'

module Twirp

  # Valid Twirp error codes and their mapping to related HTTP status.
  # This can also be used to check if a code is valid (check if not nil).
  ERROR_CODES_TO_HTTP_STATUS = {
    canceled:             408, # RequestTimeout
    invalid_argument:     400, # BadRequest
    deadline_exceeded:    408, # RequestTimeout
    not_found:            404, # Not Found
    bad_route:            404, # Not Found
    already_exists:       409, # Conflict
    permission_denied:    403, # Forbidden
    unauthenticated:      401, # Unauthorized
    resource_exhausted:   403, # Forbidden
    failed_precondition:  412, # Precondition Failed
    aborted:              409, # Conflict
    out_of_range:         400, # Bad Request

    internal:             500, # Internal Server Error
    unknown:              500, # Internal Server Error
    unimplemented:        501, # Not Implemented
    unavailable:          503, # Service Unavailable
    data_loss:            500, # Internal Server Error
  }

  # List of all valid error codes in Twirp
  ERROR_CODES = ERROR_CODES_TO_HTTP_STATUS.keys

  # Twirp::Error represents a valid error from a Twirp service
	class Error

    # Wrap an arbitrary error as a Twirp :internal
    def self.InternalWith(err)
      self.new :internal, err.message, "cause" => err.class.name
    end

    # Initialize a Twirp::Error
    # The code MUST be one of the valid ERROR_CODES Symbols (e.g. :internal, :not_found, :permission_denied ...).
    # The msg is a String with the error message.
    # The meta is optional error metadata, if included it MUST be a Hash with String keys and values.
    def initialize(code, msg, meta=nil)
      @code = validate_code(code)
      @msg = msg.to_s
      @meta = validate_meta(meta)
    end

    attr_reader :code
    attr_reader :msg
    
    def meta(key)
      @meta ||= {}
      @meta[key]
    end

    def add_meta(key, value)
      validate_meta_key_value(key, value)
      @meta ||= {}
      @meta[key] = value
    end

    def delete_meta(key)
      @meta ||= {}
      @meta.delete(key.to_s)
      @meta = nil if @meta.size == 0
    end

    def as_json
      h = {
        code: @code,
        msg: @msg,
      }
      h[:meta] = @meta if @meta
      h
    end

    def to_json
      JSON.generate(as_json)
    end

    def to_s
      "Twirp::Error code:#{code} msg:#{msg.inspect} meta:#{meta.inspect}"
    end

    private

    def validate_code(code)
      if !code.is_a? Symbol
        raise ArgumentError.new("Twirp::Error code must be a Symbol, but it is a #{code.class.to_s}")
      end
      if !ERROR_CODES_TO_HTTP_STATUS.has_key? code
        raise ArgumentError.new("Twirp::Error code :#{code} is invalid. Expected one of #{ERROR_CODES.inspect}")
      end
      code
    end

    def validate_meta(meta)
      return nil if !meta
      if !meta.is_a? Hash
        raise ArgumentError.new("Twirp::Error meta must be a Hash, but it is a #{meta.class.to_s}")
      end
      meta.each do |key, value| 
        validate_meta_key_value(key, value)        
      end
      meta
    end

    def validate_meta_key_value(key, value)
      if !key.is_a?(String) || !value.is_a?(String)
        raise ArgumentError.new("Twirp::Error meta must be a Hash with String keys and values. Invalid key<#{key.class}>: #{key.inspect}, value<#{value.class}>: #{value.inspect}")
      end
    end

  end

end
