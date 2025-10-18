module CoreLibrary
  # An interface for logging API requests and responses.
  # This class should not be instantiated but should be used as a base class
  # for API logger class.
  class ApiLogger
    # Logs the details of an HTTP request.
    # @param request [HttpRequest] The HTTP request to log.
    def log_request(request)
      raise NotImplementedError, 'This method needs to be implemented in a child class.'
    end

    # Logs the details of an HTTP response.
    # @param response [HttpResponse] The HTTP response to log.
    def log_response(response)
      raise NotImplementedError, 'This method needs to be implemented in a child class.'
    end
  end
end
