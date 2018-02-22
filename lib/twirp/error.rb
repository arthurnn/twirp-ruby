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

  def valid_error_code?(code)
    ERROR_CODES_TO_HTTP_STATUS.key? code # one of the valid symbols
  end

  # Error constructors: `Twirp.{code}_error(msg, meta=nil)` for each error code.
  # Use this constructors to ensure the errors have valid error codes. Example:
  #     Twirp.internal_error("boom")
  #     Twirp.invalid_argument_error("foo is mandatory", argument: "foo")
  #     Twirp.permission_denied_error("thou shall not pass!", target: "Balrog")
  ERROR_CODES.each do |code|
    define_singleton_method "#{code}_error" do |msg, meta=nil|
      Error.new(code, msg, meta)
    end
  end

  # Wrap another error as a Twirp::Error :internal.
  def internal_error_with(err)
    internal_error err.message, cause: err.class.name
  end

  # Twirp::Error represents an error response from a Twirp service.
  # Twirp::Error is not an Exception to be raised, but a value to be returned
  # by service handlers and received by clients.
	class Error

    attr_reader :code, :msg, :meta

    # Initialize a Twirp::Error
    # The code must be one of the valid ERROR_CODES Symbols (e.g. :internal, :not_found, :permission_denied ...).
    # The msg is a String with the error message.
    # The meta is optional error metadata, if included it must be a Hash with String values.
    def initialize(code, msg, meta=nil)
      @code = code.to_sym
      @msg = msg.to_s
      @meta = validate_meta(meta)
    end

    def to_h
      h = {
        code: @code,
        msg: @msg,
      }
      h[:meta] = @meta unless @meta.empty?
      h
    end

    def to_s
      "<Twirp::Error code:#{code.inspect} msg:#{msg.inspect} meta:#{meta.inspect}>"
    end


  private

    def validate_meta(meta)
      return {} if !meta

      if !meta.is_a? Hash
        raise ArgumentError.new("Twirp::Error meta must be a Hash, but it is a #{meta.class.to_s}")
      end
      meta.each do |key, value| 
        if !value.is_a?(String)
          raise ArgumentError.new("Twirp::Error meta values must be Strings, but key #{key.inspect} has the value <#{value.class.to_s}> #{value.inspect}")
        end
      end
      meta
    end

  end
end
