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
    def to_h; @twerr.to_h; end
    def to_s; @twerr.to_s; end
  end
end
