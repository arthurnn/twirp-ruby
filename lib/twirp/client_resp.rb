module Twirp
  class ClientResp
    attr_accessor :data
    attr_accessor :error

    def initialize(data, error)
      @data = data
      @error = error
    end
  end
end
