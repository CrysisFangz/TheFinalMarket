module CoreLibrary
  # An interface for authenticating the HTTP requests.
  # This class should not be instantiated but should be used as a base class
  # for authenticating the request.
  class Authentication
    # Checks whether this authentication scheme is valid or not.
    # @return [Boolean] True if the auth instance is valid to be applied on the request.
    def valid
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end

    # Applies the authentication scheme on the given HTTP request.
    # @param [HttpRequest] _http_request The HTTP request to apply the authentication on.
    def apply(_http_request)
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end
  end
end
