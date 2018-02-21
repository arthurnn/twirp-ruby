require_relative "./error"

module Twirp

  class Exception < StandardError

    def initialize(code, msg, meta=nil)
      @twerr = Twirp::Error.new(code, msg, meta)
    end

    def message
      "#{code}: #{msg}"
    end

    def code; @twerr.code; end
    def msg; @twerr.msg; end
    def meta; @twerr.meta; end
    def to_json; @twerr.to_json; end
    def as_json; @twerr.as_json; end
  end
end
