module CoreLibrary
  # HttpCallBack allows defining callables for pre and post API calls.
  # This class should not be instantiated but should be used as a base class
  # for capturing the request and response of an API call.
  class HttpCallback
    # A controller will call this method before making an HTTP Request.
    # @param [HttpRequest] _http_request The HttpRequest object which the HttpClient will execute.
    def on_before_request(_http_request)
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end

    # A controller will call this method after making an HTTP Request.
    # @param [HttpResponse] _http_response The HttpResponse of the API call.
    def on_after_response(_http_response)
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end
  end
end
