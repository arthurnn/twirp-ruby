require 'faraday'
require 'json'

module Twirp

  class JSONClient

    def initialize(opts)
      @package = opts[:package] || ""
      @service = opts[:service] || raise ArgumentError.new("service is required")
      @conn = opts[:conn] ||
        Faraday.new(url: opts[:url] || "http://localhost:3000") # default Webrick port
    end

    def service_path
      @package.empty? ? @service : "#{@package}.#{@service}"
    end

    def rpc_path(rpc_method)
      "/#{service_path}/#{rpc_method}"
    end

    def rpc(rpc_method, attrs={})
      resp = @conn.post do |r|
        r.url rpc_path(rpc_method)
        r.headers['Content-Type'] = 'application/json'
        r.body = JSON.generate(attrs)
      end

      if resp.status != 200
        return error_from_respone
      end

      JSON.parse(resp.body)
    end

    def error_from_respone(resp)
      Error.internal("fake client error")

      # TODO ...
      # if resp.headers['Content-Type'] == 'application/json'
      # err = error_from_respone(resp)
      #   err_attrs = JSON.parse(resp.body)
      #   Error.new(err_attrs["code"], err_attrs["msg"], err_attrs["meta"])
      # rescue JSON::ParserError => e
      #   Error.internal(e.message)  
      # end

      # Go implementation
      # // errorFromResponse builds a twirp.Error from a non-200 HTTP response.
      # // If the response has a valid serialized Twirp error, then it's returned.
      # // If not, the response status code is used to generate a similar twirp
      # // error. See twirpErrorFromIntermediary for more info on intermediary errors.
      # func errorFromResponse(resp *http.Response) twirp.Error {
      #   statusCode := resp.StatusCode
      #   statusText := http.StatusText(statusCode)
      # 
      #   if isHTTPRedirect(statusCode) {
      #     // Unexpected redirect: it must be an error from an intermediary.
      #     // Twirp clients don't follow redirects automatically, Twirp only handles
      #     // POST requests, redirects should only happen on GET and HEAD requests.
      #     location := resp.Header.Get("Location")
      #     msg := fmt.Sprintf("unexpected HTTP status code %d %q received, Location=%q", statusCode, statusText, location)
      #     return twirpErrorFromIntermediary(statusCode, msg, location)
      #   }
      # 
      #   respBodyBytes, err := ioutil.ReadAll(resp.Body)
      #   if err != nil {
      #     return clientError("failed to read server error response body", err)
      #   }
      #   var tj twerrJSON
      #   if err := json.Unmarshal(respBodyBytes, &tj); err != nil {
      #     // Invalid JSON response; it must be an error from an intermediary.
      #     msg := fmt.Sprintf("Error from intermediary with HTTP status code %d %q", statusCode, statusText)
      #     return twirpErrorFromIntermediary(statusCode, msg, string(respBodyBytes))
      #   }
      # 
      #   errorCode := twirp.ErrorCode(tj.Code)
      #   if !twirp.IsValidErrorCode(errorCode) {
      #     msg := "invalid type returned from server error response: " + tj.Code
      #     return twirp.InternalError(msg)
      #   }
      # 
      #   twerr := twirp.NewError(errorCode, tj.Msg)
      #   for k, v := range tj.Meta {
      #     twerr = twerr.WithMeta(k, v)
      #   }
      #   return twerr
      # }
    end

  end
end
