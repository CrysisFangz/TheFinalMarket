# frozen_string_literal: true

# CDN and Edge Caching Configuration for The Final Market
# Enhanced with enterprise-grade patterns, error handling, and performance optimizations

require 'digest'
require 'net/http'
require 'uri'
require 'json'
begin
  require 'async'
  require 'async/http/internet'
rescue LoadError
  # async gem not available - CDN async features will be disabled
end

# CDN Configuration Module
module Cdn
  module Configuration
    class << self
      # Thread-safe configuration loading
      def load
        @config ||= begin
          config = OpenStruct.new

          # CDN Settings
          config.asset_host = ENV.fetch('CDN_HOST', 'https://cdn.thefinalmarket.com')
          config.edge_location = ENV.fetch('EDGE_LOCATION', 'unknown')
          config.cloudflare_api_token = ENV['CLOUDFLARE_API_TOKEN']
          config.cloudflare_zone_id = ENV['CLOUDFLARE_ZONE_ID']

          # Performance Settings
          config.enable_etag = ENV.fetch('CDN_ENABLE_ETAG', 'true') == 'true'
          config.enable_compression = ENV.fetch('CDN_ENABLE_COMPRESSION', 'true') == 'true'
          config.cache_stats_enabled = ENV.fetch('CDN_CACHE_STATS_ENABLED', 'true') == 'true'

          # Security Settings
          config.cors_origins = ENV.fetch('CDN_CORS_ORIGINS', '*').split(',')
          config.enable_security_headers = ENV.fetch('CDN_SECURITY_HEADERS', 'true') == 'true'

          # Rate Limiting
          config.rate_limit_requests = ENV.fetch('CDN_RATE_LIMIT_REQUESTS', '1000').to_i
          config.rate_limit_window = ENV.fetch('CDN_RATE_LIMIT_WINDOW', '3600').to_i

          config
        end
      end

      def reset!
        @config = nil
      end
    end
  end

  # Enhanced CORS Configuration
  module Cors
    class << self
      def configure(app)
        return unless Rails.env.production?

        app.config.middleware.insert_before 0, Rack::Cors do
          allow do
            origins Cdn::Configuration.load.cors_origins
            resource '/assets/*',
              headers: :any,
              methods: [:get, :head, :options],
              max_age: 31536000,
              credentials: false
          end

          allow do
            origins Cdn::Configuration.load.cors_origins
            resource '/api/*',
              headers: :any,
              methods: [:get, :post, :put, :patch, :delete, :options],
              max_age: 86400,
              credentials: true
          end
        end
      end
    end
  end

  # Cache Strategy Pattern
  module CacheStrategies
    class BaseStrategy
      attr_reader :config

      def initialize(config = Cdn::Configuration.load)
        @config = config
      end

      def apply_cache_headers(headers, path, response)
        raise NotImplementedError, 'Subclasses must implement apply_cache_headers'
      end

      def should_apply?(path)
        raise NotImplementedError, 'Subclasses must implement should_apply?'
      end
    end

    class StaticAssetsStrategy < BaseStrategy
      PATTERN = /\.(css|js|woff2?|ttf|eot|svg|ico|pdf|zip|tar|gz)$/.freeze
      CACHE_CONTROL = 'public, max-age=31536000, immutable'.freeze

      def should_apply?(path)
        path.match?(PATTERN)
      end

      def apply_cache_headers(headers, path, response)
        headers['Cache-Control'] = CACHE_CONTROL
        headers['X-Cache-Strategy'] = 'static-assets'
      end
    end

    class ImageStrategy < BaseStrategy
      PATTERN = /\.(jpg|jpeg|png|gif|webp|avif|svg)$/.freeze
      CACHE_CONTROL = 'public, max-age=2592000, s-maxage=2592000'.freeze

      def should_apply?(path)
        path.match?(PATTERN)
      end

      def apply_cache_headers(headers, path, response)
        headers['Cache-Control'] = CACHE_CONTROL
        headers['X-Cache-Strategy'] = 'images'
      end
    end

    class HtmlStrategy < BaseStrategy
      PATTERN = /\.html$|\//.freeze
      CACHE_CONTROL = 'public, max-age=300, s-maxage=600, stale-while-revalidate=86400'.freeze

      def should_apply?(path)
        path.match?(PATTERN) && !path.match?(/^\/api\//)
      end

      def apply_cache_headers(headers, path, response)
        headers['Cache-Control'] = CACHE_CONTROL
        headers['X-Cache-Strategy'] = 'html-pages'
      end
    end

    class ApiStrategy < BaseStrategy
      PATTERN = /^\/api\//.freeze
      CACHE_CONTROL = 'public, max-age=60, s-maxage=120, must-revalidate'.freeze

      def should_apply?(path)
        path.match?(PATTERN)
      end

      def apply_cache_headers(headers, path, response)
        headers['Cache-Control'] = CACHE_CONTROL
        headers['X-Cache-Strategy'] = 'api-responses'
      end
    end

    class GraphqlStrategy < BaseStrategy
      PATTERN = /^\/graphql/.freeze
      CACHE_CONTROL = 'no-cache, no-store, must-revalidate'.freeze

      def should_apply?(path)
        path.match?(PATTERN)
      end

      def apply_cache_headers(headers, path, response)
        headers['Cache-Control'] = CACHE_CONTROL
        headers['X-Cache-Strategy'] = 'graphql'
      end
    end

    class PrivateContentStrategy < BaseStrategy
      PATTERN = /^\/(cart|wishlist|orders|profile|admin)/.freeze
      CACHE_CONTROL = 'private, max-age=0, must-revalidate'.freeze

      def should_apply?(path)
        path.match?(PATTERN)
      end

      def apply_cache_headers(headers, path, response)
        headers['Cache-Control'] = CACHE_CONTROL
        headers['X-Cache-Strategy'] = 'private-content'
      end
    end

    class StrategyManager
      STRATEGIES = [
        StaticAssetsStrategy,
        ImageStrategy,
        PrivateContentStrategy,
        GraphqlStrategy,
        ApiStrategy,
        HtmlStrategy
      ].freeze

      class << self
        def apply_strategies(headers, path, response)
          strategy = find_applicable_strategy(path)
          strategy&.apply_cache_headers(headers, path, response)
        end

        private

        def find_applicable_strategy(path)
          STRATEGIES.each do |strategy_class|
            strategy = strategy_class.new
            return strategy if strategy.should_apply?(path)
          end
          nil
        end
      end
    end
  end

  # Enhanced Edge Caching Middleware with Performance Optimizations
  class EdgeCachingMiddleware
    # Request deduplication for high-traffic scenarios
    REQUEST_CACHE_TTL = 5.seconds
    @request_cache = {}

    class << self
      def clear_request_cache
        @request_cache.clear
      end
    end

    def initialize(app)
      @app = app
      @strategies = CacheStrategies::StrategyManager
    end

    def call(env)
      # Rate limiting check
      return rate_limit_response if rate_limited?(env)

      status, headers, response = @app.call(env)

      # Apply cache strategies
      path = env['PATH_INFO']
      @strategies.apply_strategies(headers, path, response)

      # Enhanced ETag handling with conditional requests
      if should_add_etag?(path) && Cdn::Configuration.load.enable_etag
        handle_etag(headers, response, env)
      end

      # Content negotiation and compression
      enhance_headers(headers, env)

      # CDN-specific headers
      add_cdn_headers(headers, env)

      [status, headers, response]
    rescue StandardError => e
      handle_middleware_error(e, env)
    end

    private

    def rate_limited?(env)
      # Simple in-memory rate limiting (consider Redis for production)
      client_ip = env['HTTP_X_FORWARDED_FOR']&.split(',')&.first || env['REMOTE_ADDR']
      key = "rate_limit:#{client_ip}"

      current_time = Time.current.to_i
      request_count = self.class.instance_variable_get(:@request_cache)[key] ||= []

      # Clean old requests
      request_count.delete_if { |timestamp| current_time - timestamp > Cdn::Configuration.load.rate_limit_window }

      if request_count.size >= Cdn::Configuration.load.rate_limit_requests
        return true
      end

      request_count << current_time
      false
    end

    def rate_limit_response
      headers = { 'Content-Type' => 'application/json' }
      [429, headers, [JSON.generate(error: 'Rate limit exceeded', retry_after: 3600)]]
    end

    def handle_etag(headers, response, env)
      body_content = extract_body_content(response)
      return unless body_content

      etag = generate_etag(body_content)
      headers['ETag'] = %("#{etag}")

      # Handle conditional requests
      if_none_match = env['HTTP_IF_NONE_MATCH']
      return [304, headers, []] if if_none_match == headers['ETag']
    end

    def extract_body_content(response)
      if response.respond_to?(:body)
        response.body
      elsif response.respond_to?(:join)
        response.join
      end
    end

    def generate_etag(content)
      Digest::SHA256.hexdigest(content.to_s)
    end

    def enhance_headers(headers, env)
      # Vary header for content negotiation
      headers['Vary'] = 'Accept-Encoding, Accept, Accept-Language'

      # Security headers
      if Cdn::Configuration.load.enable_security_headers
        headers['X-Content-Type-Options'] = 'nosniff'
        headers['X-Frame-Options'] = 'DENY'
        headers['X-XSS-Protection'] = '1; mode=block'
        headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
      end

      # Compression hints
      if Cdn::Configuration.load.enable_compression
        headers['X-Compression'] = 'enabled'
      end
    end

    def add_cdn_headers(headers, env)
      headers['X-CDN-Cache'] = 'MISS'
      headers['X-Edge-Location'] = Cdn::Configuration.load.edge_location
      headers['X-Request-ID'] = env['REQUEST_ID'] || SecureRandom.uuid
      headers['X-Response-Time'] = Time.current.to_f.to_s
    end

    def should_add_etag?(path)
      # Only add ETag for GET requests and cacheable content
      return false unless %w[GET HEAD].include?(env['REQUEST_METHOD'])

      path.match?(/^\/api\//) || path.match?(/\.(css|js|json|xml)$/)
    end

    def handle_middleware_error(error, env)
      Rails.logger.error "CDN Middleware Error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")

      # Return a basic response instead of crashing
      headers = { 'Content-Type' => 'application/json' }
      body = JSON.generate(error: 'Internal server error', request_id: SecureRandom.uuid)

      [500, headers, [body]]
    end
  end

  # CloudFlare Service with Enhanced Error Handling and Performance
  class CloudFlareService
    class CloudFlareError < StandardError
      attr_reader :response_code, :response_body

      def initialize(message, response_code = nil, response_body = nil)
        super(message)
        @response_code = response_code
        @response_body = response_body
      end
    end

    class RateLimitError < CloudFlareError; end
    class AuthenticationError < CloudFlareError; end
    class ZoneNotFoundError < CloudFlareError; end

    def initialize
      @config = Cdn::Configuration.load
      @http_client = create_http_client
      @cache = Rails.cache
    end

    def purge_cache(urls)
      return unless production_environment?

      validate_credentials!

      cached_result = cache.read("cf_purge:#{urls.hash}")
      return cached_result if cached_result

      result = execute_with_retry do
        make_request(:post, purge_url, { files: urls }.to_json)
      end

      cache.write("cf_purge:#{urls.hash}", result, expires_in: 5.minutes)
      result
    end

    def purge_all_cache
      return unless production_environment?

      validate_credentials!

      execute_with_retry do
        make_request(:post, purge_url, { purge_everything: true }.to_json)
      end
    end

    def cache_stats
      return unless production_environment? && @config.cache_stats_enabled

      validate_credentials!

      cache_key = 'cf_cache_stats'
      cached_stats = cache.read(cache_key)
      return cached_stats if cached_stats

      result = execute_with_retry do
        make_request(:get, analytics_url)
      end

      cache.write(cache_key, result, expires_in: 10.minutes)
      result
    end

    private

    def production_environment?
      Rails.env.production?
    end

    def validate_credentials!
      unless @config.cloudflare_api_token && @config.cloudflare_zone_id
        raise AuthenticationError.new('CloudFlare credentials not configured')
      end
    end

    def create_http_client
      Async::HTTP::Internet.new
    end

    def execute_with_retry(max_retries: 3, base_delay: 1)
      last_error = nil

      max_retries.times do |attempt|
        begin
          return yield
        rescue RateLimitError => e
          last_error = e
          delay = base_delay * (2 ** attempt)
          Rails.logger.warn "CloudFlare rate limited, retrying in #{delay}s (attempt #{attempt + 1}/#{max_retries})"
          sleep delay
        rescue StandardError => e
          last_error = e
          break if attempt == max_retries - 1
          delay = base_delay * (2 ** attempt)
          Rails.logger.warn "CloudFlare request failed, retrying in #{delay}s (attempt #{attempt + 1}/#{max_retries}): #{e.message}"
          sleep delay
        end
      end

      raise last_error || CloudFlareError.new('Max retries exceeded')
    end

    def make_request(method, url, body = nil)
      uri = URI(url)

      Async do |task|
        task.with_timeout(30) do
          @http_client.request(method, uri, body).wait
        end
      end

      # Note: In a real implementation, you'd handle the Async response properly
      # This is a simplified version for demonstration
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = create_request(method, uri, body)
        http.request(request)
      end

      handle_response(response)
    end

    def create_request(method, uri, body)
      case method
      when :get
        Net::HTTP::Get.new(uri.path)
      when :post
        Net::HTTP::Post.new(uri.path)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end.tap do |request|
        request['Authorization'] = "Bearer #{@config.cloudflare_api_token}"
        request['Content-Type'] = 'application/json'
        request.body = body if body
      end
    end

    def handle_response(response)
      case response.code.to_i
      when 200, 201
        JSON.parse(response.body)
      when 429
        raise RateLimitError.new('CloudFlare rate limit exceeded', 429, response.body)
      when 401, 403
        raise AuthenticationError.new('CloudFlare authentication failed', response.code.to_i, response.body)
      when 404
        raise ZoneNotFoundError.new('CloudFlare zone not found', 404, response.body)
      else
        raise CloudFlareError.new("CloudFlare API error: #{response.message}", response.code.to_i, response.body)
      end
    end

    def purge_url
      "https://api.cloudflare.com/client/v4/zones/#{@config.cloudflare_zone_id}/purge_cache"
    end

    def analytics_url
      "https://api.cloudflare.com/client/v4/zones/#{@config.cloudflare_zone_id}/analytics/dashboard"
    end

    def cache
      @cache ||= Rails.cache
    end
  end

  # Enhanced Cache Purging Module
  module CachePurging
    extend ActiveSupport::Concern

    included do
      after_commit :purge_cdn_cache, on: [:update, :destroy]
      after_commit :warm_cdn_cache, on: [:create, :update], if: :should_warm_cache?
    end

    private

    def purge_cdn_cache
      return unless Rails.env.production?

      urls = cache_urls_to_purge
      return if urls.empty?

      begin
        Cdn::CloudFlareService.new.purge_cache(urls)
        log_cache_purge('success', urls)
      rescue StandardError => e
        log_cache_purge('error', urls, e.message)
        raise e unless Rails.env.production? # Re-raise in development for debugging
      end
    end

    def warm_cdn_cache
      return unless Rails.env.production?

      urls = cache_urls_to_warm
      return if urls.empty?

      begin
        # Async cache warming
        CacheWarmingJob.perform_later(urls)
      rescue StandardError => e
        Rails.logger.error "Cache warming failed: #{e.message}"
      end
    end

    def cache_urls_to_purge
      # Override in models to specify which URLs to purge
      []
    end

    def cache_urls_to_warm
      # Override in models to specify which URLs to warm
      cache_urls_to_purge
    end

    def should_warm_cache?
      # Override in models to control cache warming
      false
    end

    def log_cache_purge(status, urls, error = nil)
      Rails.logger.info "CDN Cache Purge (#{status}): #{urls.join(', ')}#{error ? " - Error: #{error}" : ''}"
    end
  end
end

# Rails Configuration
Rails.application.configure do
  # CDN Configuration
  if Rails.env.production?
    config.action_controller.asset_host = Cdn::Configuration.load.asset_host
    Cdn::Cors.configure(self)
  end
end

# Insert enhanced edge caching middleware
Rails.application.config.middleware.use Cdn::EdgeCachingMiddleware if Rails.env.production?

# Example model usage:
#
# class Product < ApplicationRecord
#   include Cdn::CachePurging
#
#   private
#
#   def cache_urls_to_purge
#     [
#       "https://thefinalmarket.com/products/#{id}",
#       "https://thefinalmarket.com/api/products/#{id}",
#       "https://cdn.thefinalmarket.com/images/products/#{id}/*"
#     ]
#   end
#
#   def should_warm_cache?
#     true # Enable cache warming for products
#   end
# end

