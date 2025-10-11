# frozen_string_literal: true

# CDN and Edge Caching Configuration for The Final Market

Rails.application.configure do
  # Enable CDN in production
  if Rails.env.production?
    # CloudFlare CDN configuration
    config.action_controller.asset_host = ENV.fetch('CDN_HOST', 'https://cdn.thefinalmarket.com')
    
    # Enable CORS for CDN assets
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '/assets/*',
          headers: :any,
          methods: [:get, :options],
          max_age: 31536000
      end
    end
  end
end

# Edge Caching Middleware
class EdgeCachingMiddleware
  CACHE_CONTROL_RULES = {
    # Static assets - cache for 1 year
    /\.(css|js|woff2?|ttf|eot|svg|ico)$/ => 'public, max-age=31536000, immutable',
    
    # Images - cache for 30 days
    /\.(jpg|jpeg|png|gif|webp|avif)$/ => 'public, max-age=2592000, s-maxage=2592000',
    
    # HTML pages - stale-while-revalidate
    /\.html$/ => 'public, max-age=300, s-maxage=600, stale-while-revalidate=86400',
    
    # API responses - short cache with validation
    /^\/api\// => 'public, max-age=60, s-maxage=120, must-revalidate',
    
    # GraphQL - no cache (use persisted queries instead)
    /^\/graphql/ => 'no-cache, no-store, must-revalidate',
    
    # User-specific content - private cache
    /^\/(cart|wishlist|orders|profile)/ => 'private, max-age=0, must-revalidate'
  }.freeze
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    status, headers, response = @app.call(env)
    
    # Apply cache control rules
    path = env['PATH_INFO']
    CACHE_CONTROL_RULES.each do |pattern, cache_control|
      if path.match?(pattern)
        headers['Cache-Control'] = cache_control
        break
      end
    end
    
    # Add ETag for validation
    if should_add_etag?(path)
      body_content = response.respond_to?(:body) ? response.body : response.join
      etag = Digest::MD5.hexdigest(body_content)
      headers['ETag'] = %("#{etag}")
      
      # Check If-None-Match header
      if env['HTTP_IF_NONE_MATCH'] == headers['ETag']
        return [304, headers, []]
      end
    end
    
    # Add Vary header for content negotiation
    headers['Vary'] = 'Accept-Encoding, Accept'
    
    # Add CDN-specific headers
    headers['X-CDN-Cache'] = 'MISS'
    headers['X-Edge-Location'] = ENV.fetch('EDGE_LOCATION', 'unknown')
    
    [status, headers, response]
  end
  
  private
  
  def should_add_etag?(path)
    # Add ETag for API responses and static assets
    path.match?(/^\/api\//) || path.match?(/\.(css|js|json)$/)
  end
end

# Insert edge caching middleware
Rails.application.config.middleware.use EdgeCachingMiddleware if Rails.env.production?

# CloudFlare specific configuration
module CloudFlare
  class << self
    # Purge cache for specific URLs
    def purge_cache(urls)
      return unless Rails.env.production?
      
      api_token = ENV['CLOUDFLARE_API_TOKEN']
      zone_id = ENV['CLOUDFLARE_ZONE_ID']
      
      return unless api_token && zone_id
      
      uri = URI("https://api.cloudflare.com/client/v4/zones/#{zone_id}/purge_cache")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{api_token}"
      request['Content-Type'] = 'application/json'
      request.body = { files: urls }.to_json
      
      response = http.request(request)
      JSON.parse(response.body)
    end
    
    # Purge all cache
    def purge_all_cache
      return unless Rails.env.production?
      
      api_token = ENV['CLOUDFLARE_API_TOKEN']
      zone_id = ENV['CLOUDFLARE_ZONE_ID']
      
      return unless api_token && zone_id
      
      uri = URI("https://api.cloudflare.com/client/v4/zones/#{zone_id}/purge_cache")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{api_token}"
      request['Content-Type'] = 'application/json'
      request.body = { purge_everything: true }.to_json
      
      response = http.request(request)
      JSON.parse(response.body)
    end
    
    # Get cache statistics
    def cache_stats
      return unless Rails.env.production?
      
      api_token = ENV['CLOUDFLARE_API_TOKEN']
      zone_id = ENV['CLOUDFLARE_ZONE_ID']
      
      return unless api_token && zone_id
      
      uri = URI("https://api.cloudflare.com/client/v4/zones/#{zone_id}/analytics/dashboard")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri.path)
      request['Authorization'] = "Bearer #{api_token}"
      
      response = http.request(request)
      JSON.parse(response.body)
    end
  end
end

# Automatic cache purging on model updates
module CachePurging
  extend ActiveSupport::Concern
  
  included do
    after_commit :purge_cdn_cache, on: [:update, :destroy]
  end
  
  private
  
  def purge_cdn_cache
    return unless Rails.env.production?
    
    urls = cache_urls_to_purge
    CloudFlare.purge_cache(urls) if urls.any?
  end
  
  def cache_urls_to_purge
    # Override in models to specify which URLs to purge
    []
  end
end

# Example: Include in Product model
# class Product < ApplicationRecord
#   include CachePurging
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
# end

