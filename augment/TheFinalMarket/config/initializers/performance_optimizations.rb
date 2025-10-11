# frozen_string_literal: true

# Performance Optimizations for The Final Market

Rails.application.configure do
  # Enable HTTP/2 Server Push
  config.action_dispatch.default_headers.merge!({
    'Link' => '</assets/application.css>; rel=preload; as=style, </assets/application.js>; rel=preload; as=script'
  })
  
  # Enable Brotli compression
  config.middleware.insert_before ActionDispatch::Static, Rack::Deflater
  
  # Enable connection pooling
  config.database_connection_pool_size = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
  
  # Enable query caching
  config.active_record.cache_versioning = true
  config.active_record.collection_cache_versioning = true
  
  # Enable automatic query logging for slow queries
  config.active_record.warn_on_records_fetched_greater_than = 1000
  
  # Enable parallel testing
  config.active_support.test_parallelization_threshold = 50
end

# Rack::Attack for rate limiting and throttling
if defined?(Rack::Attack)
  class Rack::Attack
    # Throttle all requests by IP
    throttle('req/ip', limit: 300, period: 5.minutes) do |req|
      req.ip unless req.path.start_with?('/assets')
    end
    
    # Throttle API requests
    throttle('api/ip', limit: 100, period: 1.minute) do |req|
      req.ip if req.path.start_with?('/api') || req.path.start_with?('/graphql')
    end
    
    # Throttle login attempts
    throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
      req.ip if req.path == '/login' && req.post?
    end
    
    # Throttle signup attempts
    throttle('signups/ip', limit: 3, period: 1.hour) do |req|
      req.ip if req.path == '/signup' && req.post?
    end
    
    # Block suspicious requests
    blocklist('block suspicious requests') do |req|
      # Block requests with suspicious user agents
      Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 1.minute, bantime: 1.hour) do
        req.user_agent.to_s.match?(/bot|crawler|spider/i) && !req.path.start_with?('/assets')
      end
    end
    
    # Custom response for throttled requests
    self.throttled_responder = lambda do |env|
      retry_after = (env['rack.attack.match_data'] || {})[:period]
      [
        429,
        {
          'Content-Type' => 'application/json',
          'Retry-After' => retry_after.to_s
        },
        [{ error: 'Rate limit exceeded. Please try again later.' }.to_json]
      ]
    end
  end
  
  Rails.application.config.middleware.use Rack::Attack
end

# Connection pooling for Redis
if defined?(Redis)
  REDIS_POOL = ConnectionPool.new(size: 10, timeout: 5) do
    Redis.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
      driver: :hiredis,
      reconnect_attempts: 3,
      reconnect_delay: 0.5,
      reconnect_delay_max: 5
    )
  end
  
  # Use Redis pool for caching
  Rails.application.config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    pool_size: 10,
    pool_timeout: 5,
    connect_timeout: 1,
    read_timeout: 1,
    write_timeout: 1,
    reconnect_attempts: 3,
    error_handler: -> (method:, returning:, exception:) {
      Rails.logger.error("Redis error: #{exception.message}")
    }
  }
end

# Database query optimization
module DatabaseOptimizations
  extend ActiveSupport::Concern
  
  class_methods do
    # Batch loading to prevent N+1 queries
    def with_associations(*associations)
      includes(*associations).references(*associations)
    end
    
    # Efficient counting with caching
    def cached_count(cache_key = nil, expires_in: 1.hour)
      cache_key ||= "#{table_name}:count"
      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        count
      end
    end
    
    # Efficient exists check
    def exists_cached?(id, expires_in: 5.minutes)
      Rails.cache.fetch("#{table_name}:exists:#{id}", expires_in: expires_in) do
        exists?(id)
      end
    end
  end
end

ActiveRecord::Base.include DatabaseOptimizations

# Fragment caching helpers
module FragmentCachingHelpers
  # Cache product card
  def cache_product_card(product, &block)
    cache([product, 'card', product.updated_at], expires_in: 1.hour, &block)
  end
  
  # Cache user profile
  def cache_user_profile(user, &block)
    cache([user, 'profile', user.updated_at], expires_in: 30.minutes, &block)
  end
  
  # Cache category list
  def cache_category_list(&block)
    cache('categories:list', expires_in: 1.day, &block)
  end
end

ActionView::Base.include FragmentCachingHelpers

# Eager loading configuration
Rails.application.config.after_initialize do
  # Preload frequently accessed data
  if Rails.env.production?
    Rails.cache.fetch('categories:all', expires_in: 1.day) do
      Category.all.to_a
    end
    
    Rails.cache.fetch('popular_products', expires_in: 1.hour) do
      Product.order(views_count: :desc).limit(20).to_a
    end
  end
end

# Memory profiling (development only)
if Rails.env.development?
  require 'memory_profiler'
  
  # Profile memory usage for specific actions
  module MemoryProfiling
    def profile_memory(&block)
      report = MemoryProfiler.report(&block)
      report.pretty_print
    end
  end
  
  ActionController::Base.include MemoryProfiling
end

# Request timeout
if defined?(Rack::Timeout)
  Rack::Timeout.timeout = 30  # 30 seconds
  Rack::Timeout.wait_timeout = 30
  Rack::Timeout.service_timeout = 25
end

# Bullet gem configuration (development only)
if Rails.env.development? && defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = false
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
  
  # Detect N+1 queries
  Bullet.n_plus_one_query_enable = true
  
  # Detect unused eager loading
  Bullet.unused_eager_loading_enable = true
  
  # Detect counter cache
  Bullet.counter_cache_enable = true
end

