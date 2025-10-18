module CoreLibrary
  # An interface for the methods that an HTTP Client must implement.
  # This class should not be instantiated but should be used as a base class
  # for HTTP Client class.
  class HttpClient
    # Execute an HttpRequest when the response is expected to be binary.
    # @param [HttpRequest] _http_request The HttpRequest to be executed.
    def execute(_http_request)
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end

    # Converts the HTTP Response from the client to an HttpResponse object.
    # @param [Dynamic] _response The response object received from the client.
    # @param [HttpRequest] _http_request The HttpRequest which was executed.
    def convert_response(_response, _http_request)
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end
  end
end
