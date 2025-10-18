require 'faraday/http_cache'
require 'faraday/retry'
require 'faraday/multipart'
require 'faraday/follow_redirects'
require 'faraday/gzip'
require 'faraday/net_http_persistent'

module CoreLibrary
  # An implementation of HttpClient.
  class FaradayClient < CoreLibrary::HttpClient
    # The attribute readers for properties.
    attr_reader :connection, :response_factory

    # The constructor.
    # @param [ClientConfiguration] client_configuration The configurations for the Faraday client.
    def initialize(client_configuration)
      @response_factory = client_configuration.response_factory
      @connection = if client_configuration.connection.nil?
                      create_connection(client_configuration)
                    else
                      client_configuration.connection
                    end
    end

    # Method to initialize connection.
    # @param [ClientConfiguration] client_configuration The configurations for the Faraday client.
    def create_connection(client_configuration)
      Faraday.new do |faraday|
        faraday.use Faraday::HttpCache, serializer: Marshal if client_configuration.cache
        faraday.use Faraday::FollowRedirects::Middleware
        faraday.request :gzip
        faraday.request :multipart
        faraday.request :url_encoded
        faraday.ssl[:ca_file] = Certifi.where
        faraday.ssl[:verify] = client_configuration.verify
        faraday.request :retry,
                        max: client_configuration.max_retries,
                        interval: client_configuration.retry_interval,
                        backoff_factor: client_configuration.backoff_factor,
                        retry_statuses: client_configuration.retry_statuses,
                        methods: client_configuration.retry_methods,
                        retry_if: proc { |env, _exc|
                          env.request.context['forced_retry'] ||= false
                        }
        faraday.adapter client_configuration.adapter
        faraday.options[:params_encoder] = Faraday::FlatParamsEncoder
        faraday.options[:timeout] = client_configuration.timeout if client_configuration.timeout.positive?
        faraday.proxy = client_configuration.proxy_settings&.to_h
      end
    end

    # Method overridden from HttpClient.
    # @param [HttpRequest] http_request The HttpRequest to be executed.
    def execute(http_request)
      response = @connection.send(
        http_request.http_method.downcase,
        http_request.query_url
      ) do |request|
        request.headers = http_request.headers.map { |k, v| [k.to_s, v.to_s] }
        request.options.context ||= {}
        request.options.context.merge!(http_request.context)
        request.body = http_request.parameters
      end
      convert_response(response, http_request)
    end

    # Method overridden from HttpClient.
    # @param [Dynamic] response The response object received from the client.
    # @param [HttpRequest] http_request The HttpRequest which was executed.
    def convert_response(response, http_request)
      @response_factory.create(response.status, response.reason_phrase,
                               response.headers, response.body, http_request)
    end
  end
end
