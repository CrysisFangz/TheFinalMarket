module CoreLibrary
  # An interface for the methods that an HTTP Client Configuration must implement.
  # This class should not be instantiated but should be used as a base class
  # for HTTP Client Configuration class.
  class ClientConfiguration
    attr_reader :timeout, :max_retries, :retry_interval, :backoff_factor, :retry_statuses,
                :retry_methods, :connection, :adapter, :response_factory, :cache, :verify,
                :proxy_settings
  end
end
