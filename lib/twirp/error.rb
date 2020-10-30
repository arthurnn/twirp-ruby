# Copyright 2018 Twitch Interactive, Inc.  All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not
# use this file except in compliance with the License. A copy of the License is
# located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

module Twirp

  # Valid Twirp error codes and their mapping to related HTTP status.
  # This can also be used to check if a code is valid (check if not nil).
  ERROR_CODES_TO_HTTP_STATUS = {
    canceled:             408, # Request Timeout
    invalid_argument:     400, # Bad Request
    malformed:            400, # Bad Request
    deadline_exceeded:    408, # Request Timeout
    not_found:            404, # Not Found
    bad_route:            404, # Not Found
    already_exists:       409, # Conflict
    permission_denied:    403, # Forbidden
    unauthenticated:      401, # Unauthorized
    resource_exhausted:   429, # Too Many Requests
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


  # Twirp::Error represents an error response from a Twirp service.
  # Twirp::Error is not an Exception to be raised, but a value to be returned
  # by service handlers and received by clients.
  class Error

    def self.valid_code?(code)
      ERROR_CODES_TO_HTTP_STATUS.key? code # one of the valid symbols
    end

    # Code constructors to ensure valid error codes. Example:
    #     Twirp::Error.internal("boom")
    #     Twirp::Error.invalid_argument("foo is mandatory", mymeta: "foobar")
    #     Twirp::Error.permission_denied("Thou shall not pass!", target: "Balrog")
    ERROR_CODES.each do |code|
      define_singleton_method code do |msg, meta=nil|
        new(code, msg, meta)
      end
    end

    # Wrap another error as a Twirp::Error :internal.
    def self.internal_with(err)
      twerr = internal err.message, cause: err.class.name
      twerr.cause = err # availabe in error hook for inspection, but not in the response
      twerr
    end

    attr_reader :code, :msg, :meta

    attr_accessor :cause # used when wrapping another error, but this is not serialized

    # Initialize a Twirp::Error
    # The code must be one of the valid ERROR_CODES Symbols (e.g. :internal, :not_found, :permission_denied ...).
    # The msg is a String with the error message.
    # The meta is optional error metadata, if included it must be a Hash with String values.
    def initialize(code, msg, meta=nil)
      @code = code.to_sym
      @msg = msg.to_s
      @meta = validate_meta(meta)
    end

    # Key-value representation of the error. Can be directly serialized into JSON.
    def to_h
      h = {
        code: @code,
        msg: @msg,
      }
      h[:meta] = @meta unless @meta.empty?
      h
    end

    def to_s
      "<Twirp::Error code:#{code} msg:#{msg.inspect} meta:#{meta.inspect}>"
    end

    def inspect
      to_s
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
