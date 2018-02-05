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

    attr_reader :code # Symbol for the Twirp Error Code (:internal, :not_found, :permission_denied, etc.)
    attr_reader :msg # String with the error message.  
    attr_reader :meta # Optional hash with error metadata. Both keys and values MUST be Strings.

    def initialize(code, msg, meta=nil)
      @code = validate_code(code)
      @msg = msg.to_s
      @meta = validate_meta(meta)
    end

    def to_json
      JSON.encode({
        :code => @code,
        :msg => @msg,
        :meta => @meta
      })
    end

private

  def validate_code(code)
    if !code.is_a? Symbol
      raise ArgumentError.new("Twirp::Error code must be a Symbol, but it is a #{code.class.to_s}")
    end
    if !ERROR_CODES_TO_HTTP_STATUS.has_key? code
      raise ArgumentError.new("Twirp::Error code :#{code} is invalid. Expected one of #{ERROR_CODES.inspect}")
    end
  end

  def validate_meta_only_strings(meta)
    return if meta == nil # ok, it is optional
    meta.each do |k, v|
      # ... TODO
    end

  end

end
