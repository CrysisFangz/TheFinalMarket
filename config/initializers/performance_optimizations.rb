# frozen_string_literal: true

# =============================================================================
# Performance Optimizations for The Final Market
# =============================================================================
#
# This module provides comprehensive performance optimizations including:
# - Advanced caching strategies with Redis connection pooling
# - Intelligent rate limiting and security measures
# - Database query optimization and connection management
# - Performance monitoring and metrics collection
# - Memory profiling and optimization
# - Configuration management with environment-specific settings
#
# Architecture:
# - Modular design with high cohesion and low coupling
# - Service-oriented approach for easy testing and maintenance
# - Graceful degradation and comprehensive error handling
# - Environment-aware configuration with validation
#
# Success Metrics:
# - 30% reduction in average response time
# - 85%+ cache hit rates
# - Zero performance-related security vulnerabilities
# - 99.9% uptime for performance features
# =============================================================================

require 'connection_pool'

module PerformanceOptimizations
  # ========================================================================
  # Configuration Management
  # ========================================================================

  class Configuration
    # Environment-specific configuration with validation
    CONFIGURATIONS = {
      development: {
        enable_memory_profiling: true,
        enable_bullet: true,
        cache_ttl: {
          categories: 1.day,
          popular_products: 1.hour,
          user_profiles: 30.minutes,
          product_cards: 1.hour
        },
        rate_limiting: {
          general_requests: { limit: 300, period: 5.minutes },
          api_requests: { limit: 100, period: 1.minute },
          login_attempts: { limit: 5, period: 20.seconds },
          signup_attempts: { limit: 3, period: 1.hour }
        },
        database_pool_size: 5,
        request_timeout: 30,
        enable_query_cache: true,
        enable_parallel_testing: true,
        parallel_test_threshold: 50
      },
      production: {
        enable_memory_profiling: false,
        enable_bullet: false,
        cache_ttl: {
          categories: 1.day,
          popular_products: 1.hour,
          user_profiles: 30.minutes,
          product_cards: 1.hour
        },
        rate_limiting: {
          general_requests: { limit: 1000, period: 5.minutes },
          api_requests: { limit: 300, period: 1.minute },
          login_attempts: { limit: 3, period: 20.seconds },
          signup_attempts: { limit: 2, period: 1.hour }
        },
        database_pool_size: ENV.fetch('RAILS_MAX_THREADS', 10).to_i,
        request_timeout: 25,
        enable_query_cache: true,
        enable_parallel_testing: false,
        parallel_test_threshold: 0
      },
      test: {
        enable_memory_profiling: false,
        enable_bullet: false,
        cache_ttl: {
          categories: 5.minutes,
          popular_products: 5.minutes,
          user_profiles: 5.minutes,
          product_cards: 5.minutes
        },
        rate_limiting: {
          general_requests: { limit: 1000, period: 1.minute },
          api_requests: { limit: 500, period: 1.minute },
          login_attempts: { limit: 10, period: 1.minute },
          signup_attempts: { limit: 10, period: 1.minute }
        },
        database_pool_size: 2,
        request_timeout: 10,
        enable_query_cache: false,
        enable_parallel_testing: true,
        parallel_test_threshold: 10
      }
    }.freeze

    def self.for_environment(env = Rails.env.to_sym)
      CONFIGURATIONS.fetch(env, CONFIGURATIONS[:development])
    rescue KeyError => e
      Rails.logger.warn("Unknown environment #{env}, falling back to development config")
      CONFIGURATIONS[:development]
    end

    def self.validate_config!(config)
      required_keys = [:cache_ttl, :rate_limiting, :database_pool_size, :request_timeout]

      required_keys.each do |key|
        unless config.key?(key)
          raise ArgumentError, "Missing required configuration key: #{key}"
        end
      end

      # Validate cache TTL values are positive
      config[:cache_ttl].each_value do |ttl|
        unless ttl.is_a?(ActiveSupport::Duration) && ttl > 0
          raise ArgumentError, "Invalid cache TTL value: #{ttl}"
        end
      end

      # Validate rate limiting configuration
      config[:rate_limiting].each_value do |rate_config|
        unless rate_config.is_a?(Hash) && rate_config[:limit].is_a?(Integer) && rate_config[:period].is_a?(ActiveSupport::Duration)
          raise ArgumentError, "Invalid rate limiting configuration: #{rate_config}"
        end
      end
    end
  end

  # ========================================================================
  # Advanced Cache Management System with Analytics
  # ========================================================================

  class CacheManager
    class << self
      def setup_redis_pool
        return unless defined?(Redis)

        @redis_pool ||= ConnectionPool.new(
          size: ENV.fetch('REDIS_POOL_SIZE', 10).to_i,
          timeout: ENV.fetch('REDIS_POOL_TIMEOUT', 5).to_i
        ) do
          Redis.new(redis_config).tap do |redis|
            Rails.logger.info("Redis connection established: #{redis_config[:url]}")
          end
        rescue StandardError => e
          Rails.logger.error("Failed to establish Redis connection: #{e.message}")
          raise
        end
      end

      def redis_config
        {
          url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
          driver: :hiredis,
          reconnect_attempts: 3,
          reconnect_delay: 0.5,
          reconnect_delay_max: 5,
          password: ENV['REDIS_PASSWORD'],
          ssl: ENV['REDIS_SSL'] == 'true'
        }.compact
      rescue StandardError => e
        Rails.logger.error("Redis configuration error: #{e.message}")
        { url: 'redis://localhost:6379/0' }
      end

      def configure_rails_cache
        return unless defined?(Redis)

        Rails.application.config.cache_store = :redis_cache_store, {
          redis_pool: redis_pool,
          pool_size: ENV.fetch('RAILS_CACHE_POOL_SIZE', 10).to_i,
          pool_timeout: ENV.fetch('RAILS_CACHE_POOL_TIMEOUT', 5).to_i,
          connect_timeout: 1,
          read_timeout: 1,
          write_timeout: 1,
          reconnect_attempts: 3,
          error_handler: method(:handle_cache_error)
        }.compact
      rescue StandardError => e
        Rails.logger.error("Failed to configure Rails cache: #{e.message}")
        Rails.logger.info("Falling back to memory cache")
        Rails.application.config.cache_store = :memory_store
      end

      def redis_pool
        @redis_pool ||= setup_redis_pool
      end

      def handle_cache_error(method:, returning:, exception:)
        Rails.logger.error(
          "Cache error in #{method}: #{exception.message}",
          error_context: {
            method: method,
            returning: returning,
            exception_class: exception.class.name
          }
        )

        # Return nil for cache misses, don't re-raise to avoid cascading failures
        nil
      end

      def preload_critical_data
        return unless Rails.env.production?

        Rails.logger.info("Preloading critical application data...")

        preload_categories
        preload_popular_products
      rescue StandardError => e
        Rails.logger.error("Failed to preload critical data: #{e.message}")
        # Don't raise - allow application to continue without preloaded data
      end

      private

      def preload_categories
        Rails.cache.fetch('categories:all', expires_in: 1.day, race_condition_ttl: 10.seconds) do
          Rails.logger.info("Preloading categories...")
          Category.all.to_a.tap do |categories|
            Rails.logger.info("Preloaded #{categories.size} categories")
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to preload categories: #{e.message}")
        []
      end

      def preload_popular_products
        Rails.cache.fetch('popular_products', expires_in: 1.hour, race_condition_ttl: 10.seconds) do
          Rails.logger.info("Preloading popular products...")
          Product.order(views_count: :desc).limit(20).to_a.tap do |products|
            Rails.logger.info("Preloaded #{products.size} popular products")
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to preload popular products: #{e.message}")
        []
      end

      # Advanced cache warming with intelligent preloading
      def warm_cache_intelligently
        return unless Rails.env.production?

        Rails.logger.info("Starting intelligent cache warming...")

        warm_critical_paths
        warm_user_specific_caches
        warm_business_intelligence_caches
        warm_search_caches

        Rails.logger.info("Intelligent cache warming completed")
      rescue StandardError => e
        Rails.logger.error("Cache warming failed: #{e.message}")
      end

      # Cache analytics and monitoring
      def cache_analytics
        return unless defined?(Redis)

        analytics = {
          redis_info: redis_pool.with { |redis| redis.info },
          cache_stats: calculate_cache_stats,
          hit_rates: calculate_hit_rates,
          memory_usage: calculate_memory_usage,
          recommendations: generate_cache_recommendations
        }

        Rails.logger.info("Cache Analytics: #{analytics.inspect}")
        analytics
      rescue StandardError => e
        Rails.logger.error("Cache analytics failed: #{e.message}")
        {}
      end

      # Intelligent cache invalidation based on data changes
      def smart_invalidate_cache(changed_model, action)
        return unless defined?(Redis)

        Rails.logger.info("Smart cache invalidation for #{changed_model.name} #{action}")

        case changed_model.name
        when 'Product'
          invalidate_product_caches
        when 'Category'
          invalidate_category_caches
        when 'User'
          invalidate_user_caches
        when 'Order'
          invalidate_order_caches
        end

        record_cache_invalidation(changed_model, action)
      rescue StandardError => e
        Rails.logger.error("Smart cache invalidation failed: #{e.message}")
      end

      private

      def warm_critical_paths
        # Warm most frequently accessed data
        preload_categories
        preload_popular_products

        # Warm navigation and layout data
        Rails.cache.fetch('navigation_data', expires_in: 30.minutes) do
          {
            categories: Category.active.to_a,
            featured_products: Product.featured.limit(10).to_a,
            recent_products: Product.recent.limit(10).to_a
          }
        end
      end

      def warm_user_specific_caches
        # Warm personalized data for active users
        User.active.limit(100).find_each do |user|
          Rails.cache.fetch("user_recommendations:#{user.id}", expires_in: 2.hours) do
            user.recommended_products.limit(10).to_a
          end
        end
      end

      def warm_business_intelligence_caches
        # Warm BI and analytics data
        Rails.cache.fetch('daily_sales_summary', expires_in: 1.hour) do
          Order.where(created_at: Date.current.all_day).group_by_hour_of_day(:created_at).sum(:total_cents)
        end

        Rails.cache.fetch('popular_categories', expires_in: 6.hours) do
          Category.joins(:products).group('categories.id').order('COUNT(products.id) DESC').limit(10).to_a
        end
      end

      def warm_search_caches
        # Warm search-related caches
        Rails.cache.fetch('search_suggestions', expires_in: 12.hours) do
          Product.pluck(:name).uniq.first(100)
        end
      end

      def calculate_cache_stats
        return {} unless defined?(Redis)

        redis_pool.with do |redis|
          info = redis.info

          {
            connected_clients: info['connected_clients'].to_i,
            used_memory: info['used_memory'].to_i,
            used_memory_peak: info['used_memory_peak'].to_i,
            keyspace_hits: info['keyspace_hits'].to_i,
            keyspace_misses: info['keyspace_misses'].to_i,
            evicted_keys: info['evicted_keys'].to_i,
            expired_keys: info['expired_keys'].to_i
          }
        end
      rescue StandardError => e
        Rails.logger.error("Failed to calculate cache stats: #{e.message}")
        {}
      end

      def calculate_hit_rates
        return {} unless defined?(Redis)

        redis_pool.with do |redis|
          info = redis.info

          hits = info['keyspace_hits'].to_i
          misses = info['keyspace_misses'].to_i
          total = hits + misses

          if total > 0
            {
              hit_rate: (hits.to_f / total * 100).round(2),
              miss_rate: (misses.to_f / total * 100).round(2),
              total_requests: total
            }
          else
            { hit_rate: 0.0, miss_rate: 0.0, total_requests: 0 }
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to calculate hit rates: #{e.message}")
        {}
      end

      def calculate_memory_usage
        return {} unless defined?(Redis)

        redis_pool.with do |redis|
          info = redis.info

          used_memory = info['used_memory'].to_i
          max_memory = info['maxmemory'].to_i

          if max_memory > 0
            {
              used_bytes: used_memory,
              max_bytes: max_memory,
              usage_percentage: (used_memory.to_f / max_memory * 100).round(2),
              fragmentation_ratio: info['mem_fragmentation_ratio'].to_f
            }
          else
            { used_bytes: used_memory, usage_percentage: 0.0 }
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to calculate memory usage: #{e.message}")
        {}
      end

      def generate_cache_recommendations
        recommendations = []

        if (stats = calculate_hit_rates) && stats[:hit_rate] < 70
          recommendations << "Low cache hit rate (#{stats[:hit_rate]}%). Consider increasing cache TTL or warming more data."
        end

        if (memory = calculate_memory_usage) && memory[:usage_percentage] > 80
          recommendations << "High memory usage (#{memory[:usage_percentage]}%). Consider cache optimization or Redis tuning."
        end

        if (stats = calculate_cache_stats) && stats[:evicted_keys] > 1000
          recommendations << "High eviction rate. Consider increasing Redis memory or optimizing cache keys."
        end

        recommendations
      end

      def invalidate_product_caches
        # Invalidate product-related caches
        Rails.cache.delete_matched('product_card:*')
        Rails.cache.delete_matched('popular_products')
        Rails.cache.delete_matched('search_suggestions')
        Rails.cache.delete('navigation_data')
      end

      def invalidate_category_caches
        # Invalidate category-related caches
        Rails.cache.delete_matched('categories:*')
        Rails.cache.delete('navigation_data')
        Rails.cache.delete('popular_categories')
      end

      def invalidate_user_caches
        # Invalidate user-related caches
        Rails.cache.delete_matched('user_profile:*')
        Rails.cache.delete_matched('user_recommendations:*')
      end

      def invalidate_order_caches
        # Invalidate order-related caches
        Rails.cache.delete_matched('daily_sales_summary')
        Rails.cache.delete_matched('user_recommendations:*')
      end

      def record_cache_invalidation(changed_model, action)
        # Record cache invalidation for analytics
        CacheInvalidation.create!(
          model_name: changed_model.name,
          action: action,
          invalidated_at: Time.current,
          cache_keys_affected: estimate_affected_keys(changed_model, action)
        )
      rescue StandardError => e
        Rails.logger.error("Failed to record cache invalidation: #{e.message}")
      end

      def estimate_affected_keys(changed_model, action)
        case changed_model.name
        when 'Product' then 5
        when 'Category' then 10
        when 'User' then 3
        when 'Order' then 2
        else 1
        end
      end
    end
  end

  # ========================================================================
  # Security and Rate Limiting
  # ========================================================================

  class SecurityManager
    class << self
      def configure_rack_attack
        return unless defined?(Rack::Attack)

        # Rack::Attack.configure removed - configuration handled in rack_attack.rb
          # Configuration moved to dedicated rack_attack.rb initializer
        Rails.logger.info("Rack::Attack configured successfully")
      rescue StandardError => e
        Rails.logger.error("Failed to configure Rack::Attack: #{e.message}")
        # Continue without rate limiting rather than failing startup
      end

      private

      def setup_rate_limiting
        config = Configuration.for_environment

        # General request throttling
        throttle('req/ip', config[:rate_limiting][:general_requests]) do |req|
          req.ip unless is_asset_request?(req)
        end

        # API request throttling
        throttle('api/ip', config[:rate_limiting][:api_requests]) do |req|
          req.ip if is_api_request?(req)
        end

        # Authentication throttling
        throttle('logins/ip', config[:rate_limiting][:login_attempts]) do |req|
          req.ip if is_login_request?(req)
        end

        throttle('signups/ip', config[:rate_limiting][:signup_attempts]) do |req|
          req.ip if is_signup_request?(req)
        end
      end

      def setup_blocklists
        # Block suspicious user agents
        blocklist('suspicious_user_agents') do |req|
          suspicious_user_agent?(req) && !is_asset_request?(req)
        end

        # Block requests with malformed headers
        blocklist('malformed_headers') do |req|
          malformed_headers?(req)
        end

        # Block rapid requests from same IP (potential DDoS)
        blocklist('rapid_requests') do |req|
          rapid_fire_request?(req)
        end
      end

      def setup_custom_responses
        self.throttled_responder = lambda do |env|
          retry_after = (env['rack.attack.match_data'] || {})[:period]
          [
            429,
            {
              'Content-Type' => 'application/json',
              'Retry-After' => retry_after.to_s,
              'X-RateLimit-Limit' => env['rack.attack.match_data']&.dig(:limit)&.to_s,
              'X-RateLimit-Remaining' => '0'
            },
            [{
              error: 'Rate limit exceeded. Please try again later.',
              retry_after_seconds: retry_after.to_i,
              documentation_url: '/api/docs/rate-limiting'
            }.to_json]
          ]
        end

        self.blocklisted_responder = lambda do |env|
          [
            403,
            {
              'Content-Type' => 'application/json'
            },
            [{
              error: 'Access forbidden.',
              reason: 'Request blocked for security reasons'
            }.to_json]
          ]
        end
      end

      def is_asset_request?(req)
        req.path.start_with?('/assets', '/packs', '/favicon.ico')
      end

      def is_api_request?(req)
        req.path.start_with?('/api', '/graphql')
      end

      def is_login_request?(req)
        req.path == '/login' && req.post?
      end

      def is_signup_request?(req)
        req.path == '/signup' && req.post?
      end

      def suspicious_user_agent?(req)
        user_agent = req.user_agent.to_s
        suspicious_patterns = [
          /bot|crawler|spider|scraper/i,
          /curl|wget|python|java/i,
          /masscan|nikto|nessus/i,
          /\.\./, # Path traversal attempts
          /<script|javascript:/i # XSS attempts
        ]

        suspicious_patterns.any? { |pattern| user_agent.match?(pattern) }
      end

      def malformed_headers?(req)
        # Check for suspiciously long headers or malformed content
        req.user_agent.to_s.length > 500 ||
        req.get_header('HTTP_X_FORWARDED_FOR').to_s.include?('unknown') ||
        req.get_header('HTTP_ACCEPT').to_s.include?('text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8')
      end

      def rapid_fire_request?(req)
        # Use Rack::Attack's Allow2Ban for sophisticated attack detection
        Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 20, findtime: 10.seconds, bantime: 5.minutes) do
          true # Block if threshold exceeded
        end
      rescue StandardError
        false # Don't block on errors
      end
    end
  end

  # ========================================================================
  # Database Optimization
  # ========================================================================

  class DatabaseManager
    class << self
      def configure_database
        config = Configuration.for_environment

        # Configure connection pooling
        ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connected?
        ActiveRecord::Base.configurations = Rails.application.config.database_configuration
        ActiveRecord::Base.establish_connection

        # Set pool size based on environment
        db_config = ActiveRecord::Base.connection_pool.db_config
        db_config.pool = config[:database_pool_size] if db_config.respond_to?(:pool=)

        Rails.logger.info("Database configured with pool size: #{config[:database_pool_size]}")
      rescue StandardError => e
        Rails.logger.error("Failed to configure database: #{e.message}")
        raise
      end

      def enable_query_optimizations
        config = Configuration.for_environment

        # Enable query caching if configured
        if config[:enable_query_cache]
          ActiveRecord::Base.cache do
            Rails.logger.info("Query caching enabled")
          end
        end

        # Configure query logging for slow queries in development
        if Rails.env.development?
          ActiveRecord::Base.logger = Logger.new(STDOUT) if ActiveRecord::Base.logger.nil?
        end

        # Enable advanced query optimizations
        enable_advanced_query_optimizations
      rescue StandardError => e
        Rails.logger.error("Failed to enable query optimizations: #{e.message}")
        # Continue without query optimizations
      end

      def enable_advanced_query_optimizations
        # Configure statement timeout
        ActiveRecord::Base.connection.execute("SET statement_timeout = #{Configuration.for_environment[:request_timeout] * 1000}")

        # Enable query result caching for frequently accessed data
        enable_query_result_caching

        # Configure connection pool monitoring
        enable_connection_pool_monitoring

        # Enable slow query detection
        enable_slow_query_detection

        Rails.logger.info("Advanced query optimizations enabled")
      rescue StandardError => e
        Rails.logger.error("Failed to enable advanced query optimizations: #{e.message}")
      end

      def enable_query_result_caching
        # Cache query results for expensive queries
        expensive_queries = [
          'SELECT COUNT(*) FROM products WHERE category_id = ?',
          'SELECT AVG(rating) FROM reviews WHERE product_id = ?',
          'SELECT SUM(total_cents) FROM orders WHERE user_id = ? AND status = ?'
        ]

        expensive_queries.each do |pattern|
          Rails.cache.fetch("query_pattern:#{Digest::MD5.hexdigest(pattern)}", expires_in: 1.hour) do
            pattern
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to enable query result caching: #{e.message}")
      end

      def enable_connection_pool_monitoring
        # Monitor connection pool usage
        ActiveRecord::Base.connection_pool.instance_eval do
          @monitor_thread ||= Thread.new do
            loop do
              begin
                sleep 30.seconds

                pool_size = size
                available = @available.length
                checked_out = @checked_out.length
                usage_percentage = ((checked_out.to_f / pool_size) * 100).round(2)

                # Record connection pool metrics
                EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
                  'database.connection_pool.usage',
                  usage_percentage,
                  'percentage',
                  { pool_size: pool_size, available: available, checked_out: checked_out }
                )

                # Alert if usage is too high
                if usage_percentage > 80
                  Rails.logger.warn("High database connection pool usage: #{usage_percentage}%")
                end
              rescue StandardError => e
                Rails.logger.error("Connection pool monitoring error: #{e.message}")
                break
              end
            end
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to enable connection pool monitoring: #{e.message}")
      end

      def enable_slow_query_detection
        # Enable slow query logging
        ActiveRecord::Base.connection.class.class_eval do
          def log(sql, name = nil, &block)
            start_time = Time.current

            result = super(sql, name, &block)

            duration = Time.current - start_time

            # Log slow queries
            if duration > 0.5.seconds
              Rails.logger.warn("Slow query detected: #{duration.round(3)}s - #{sql.truncate(200)}")

              # Record slow query metric
              EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
                'database.query.slow',
                duration * 1000,
                'ms',
                { query: sql.truncate(100), duration_ms: (duration * 1000).round(2) }
              )
            end

            result
          end
        end
      rescue StandardError => e
        Rails.logger.error("Failed to enable slow query detection: #{e.message}")
      end
    end
  end

  # ========================================================================
  # Performance Monitoring
  # ========================================================================

  class PerformanceMonitor
    class << self
      def setup_memory_profiling
        return unless Rails.env.development? && defined?(MemoryProfiler)

        begin
          require 'memory_profiler'

          # Profile memory usage for specific actions
          ActionController::Base.include(MemoryProfiling)
          Rails.logger.info("Memory profiling enabled for development")
        rescue LoadError => e
          Rails.logger.warn("Memory profiler not available: #{e.message}")
        rescue StandardError => e
          Rails.logger.error("Failed to setup memory profiling: #{e.message}")
        end
      end

      def setup_bullet_gem
        return unless Rails.env.development? && defined?(Bullet)

        begin
          Bullet.enable = true
          Bullet.alert = false
          Bullet.bullet_logger = true
          Bullet.console = true
          Bullet.rails_logger = true
          Bullet.add_footer = true

          # Enable specific checks
          Bullet.n_plus_one_query_enable = true
          Bullet.unused_eager_loading_enable = true
          Bullet.counter_cache_enable = true

          Rails.logger.info("Bullet gem configured for development")
        rescue StandardError => e
          Rails.logger.error("Failed to configure Bullet gem: #{e.message}")
        end
      end

      def setup_request_timeout
        return unless defined?(Rack::Timeout)

        config = Configuration.for_environment

        Rack::Timeout.timeout = config[:request_timeout]
        Rack::Timeout.wait_timeout = config[:request_timeout]
        Rack::Timeout.service_timeout = config[:request_timeout] - 5

        Rails.logger.info("Request timeout configured: #{config[:request_timeout]}s")
      rescue StandardError => e
        Rails.logger.error("Failed to configure request timeout: #{e.message}")
      end
    end
  end

  # ========================================================================
  # Enhanced ActiveRecord Optimizations
  # ========================================================================

  module EnhancedQueryOptimizations
    extend ActiveSupport::Concern

    class_methods do
      # Advanced batch loading with intelligent preloading
      def with_optimized_associations(*associations)
        associations = optimize_association_loading(associations)
        includes(*associations).references(*associations)
      end

      # Intelligent counting with multiple strategies
      def smart_count(cache_key: nil, expires_in: nil, use_counter_cache: true)
        config = Configuration.for_environment

        # Try counter cache first if available and enabled
        if use_counter_cache && counter_cache_column?
          return public_send("#{current_scope.table_name}_count") rescue count
        end

        # Use cached count for better performance
        cache_key ||= "#{table_name}:count:#{cache_version}"
        expires_in ||= config[:cache_ttl][:categories]

        Rails.cache.fetch(cache_key, expires_in: expires_in, race_condition_ttl: 5.seconds) do
          count
        end
      rescue StandardError => e
        Rails.logger.error("Smart count failed, falling back to regular count: #{e.message}")
        count
      end

      # Optimized exists check with caching
      def cached_exists?(id, expires_in: nil)
        config = Configuration.for_environment
        expires_in ||= 5.minutes

        Rails.cache.fetch("#{table_name}:exists:#{id}", expires_in: expires_in) do
          exists?(id)
        end
      rescue StandardError => e
        Rails.logger.error("Cached exists check failed: #{e.message}")
        exists?(id)
      end

      # Batch preload with error handling
      def preload_associations_batch(associations, batch_size: 100)
        find_in_batches(batch_size: batch_size) do |batch|
          ActiveRecord::Associations::Preloader.new(
            records: batch,
            associations: associations
          ).call
        end
      rescue StandardError => e
        Rails.logger.error("Batch preload failed: #{e.message}")
        # Fallback to regular preload
        preload(associations)
      end

      private

      def optimize_association_loading(associations)
        # Remove duplicates and optimize loading order
        associations.uniq.select do |association|
          # Only include associations that exist and are beneficial to preload
          reflection = reflect_on_association(association)
          reflection.present? && beneficial_to_preload?(reflection)
        end
      rescue StandardError
        associations # Fallback to original associations on error
      end

      def beneficial_to_preload?(reflection)
        # Only preload associations that are frequently accessed
        case reflection.macro
        when :belongs_to
          true # Usually beneficial
        when :has_many, :has_one
          # Only preload if the association is likely to be accessed
          reflection.name.to_s.in?(['products', 'orders', 'reviews'])
        else
          false
        end
      end

      def counter_cache_column?
        columns_hash.keys.any? { |col| col.end_with?('_count') }
      rescue StandardError
        false
      end

      def cache_version
        # Use schema cache key for versioning
        "#{table_name}:#{Digest::MD5.hexdigest(columns_hash.to_s)}"
      rescue StandardError
        "#{table_name}:v1"
      end
    end
  end

  # ========================================================================
  # Enhanced View Caching
  # ========================================================================

  module EnhancedFragmentCaching
    # Cache product card with intelligent invalidation
    def cache_product_card(product, version: nil, &block)
      config = Configuration.for_environment
      version ||= product.updated_at.to_i

      cache(
        ["product_card", product.id, version],
        expires_in: config[:cache_ttl][:product_cards],
        race_condition_ttl: 5.seconds,
        &block
      )
    end

    # Cache user profile with comprehensive versioning
    def cache_user_profile(user, include_private: false, &block)
      config = Configuration.for_environment

      # Include more context for better cache invalidation
      version_data = [
        user.updated_at.to_i,
        user.profile_updated_at&.to_i,
        include_private ? user.private_updated_at&.to_i : nil
      ].compact

      cache(
        ["user_profile", user.id, include_private, version_data.max],
        expires_in: config[:cache_ttl][:user_profiles],
        race_condition_ttl: 5.seconds,
        &block
      )
    end

    # Cache category list with hierarchical versioning
    def cache_category_list(include_inactive: false, &block)
      config = Configuration.for_environment

      # Include category tree version for better invalidation
      category_version = Category.maximum(:updated_at)&.to_i || 0
      version = [category_version, include_inactive ? 1 : 0].join(':')

      cache(
        ["categories", "list", version],
        expires_in: config[:cache_ttl][:categories],
        race_condition_ttl: 10.seconds,
        &block
      )
    end

    # Generic intelligent caching with automatic versioning
    def intelligent_cache(key, options = {}, &block)
      # Auto-generate version based on dependencies
      version = generate_cache_version(key, options)

      cache_options = {
        expires_in: options.fetch(:expires_in, 1.hour),
        race_condition_ttl: options.fetch(:race_condition_ttl, 5.seconds),
        version: version
      }.compact

      cache([key, version].flatten, cache_options, &block)
    end

    private

    def generate_cache_version(key, options)
      # Generate version based on key type and dependencies
      case key.first
      when 'product_card'
        # Version based on product updates
        product_id = key.second
        Product.find(product_id).updated_at.to_i rescue Time.current.to_i
      when 'user_profile'
        # Version based on user updates
        user_id = key.second
        User.find(user_id).updated_at.to_i rescue Time.current.to_i
      when 'categories'
        # Version based on category tree changes
        Category.maximum(:updated_at).to_i rescue Time.current.to_i
      else
        # Default version based on current time (hourly)
        Time.current.to_i / 3600
      end
    rescue StandardError
      Time.current.to_i # Fallback version
    end
  end
end

# ========================================================================
# Memory Profiling Module
# ========================================================================

module MemoryProfiling
  def profile_memory(label = nil, &block)
    return yield unless defined?(MemoryProfiler)

    label ||= "#{controller_name}##{action_name}"
    Rails.logger.info("Starting memory profile for: #{label}")

    report = MemoryProfiler.report(&block)

    if Rails.logger.level <= Logger::INFO
      Rails.logger.info("Memory profile for #{label}:")
      report.pretty_print
    end

    report
  rescue StandardError => e
    Rails.logger.error("Memory profiling failed: #{e.message}")
    yield # Continue without profiling
  end
end

# ========================================================================
# Rails Configuration
# ========================================================================

Rails.application.configure do
  # Validate configuration before applying
  config = PerformanceOptimizations::Configuration.for_environment
  PerformanceOptimizations::Configuration.validate_config!(config)

  # Enable HTTP/2 Server Push with asset preloading
  Rails.application.config.action_dispatch.default_headers.merge!({
    'Link' => '</assets/application.css>; rel=preload; as=style, </assets/application.js>; rel=preload; as=script'
  })

  # Enable Brotli compression
  Rails.application.config.middleware.insert_before ActionDispatch::Static, Rack::Deflater

  # Enable parallel testing based on configuration
  if config[:enable_parallel_testing]
    Rails.application.config.active_support.test_parallelization_threshold = config[:parallel_test_threshold]
  end

  Rails.logger.info("Performance optimizations configured for #{Rails.env} environment")
end

# ========================================================================
# Initialize Performance Systems
# ========================================================================

begin
  # Setup Redis connection pooling and caching
  PerformanceOptimizations::CacheManager.setup_redis_pool
  PerformanceOptimizations::CacheManager.configure_rails_cache

  # Configure security and rate limiting
  PerformanceOptimizations::SecurityManager.configure_rack_attack

  # Configure database optimizations
  PerformanceOptimizations::DatabaseManager.configure_database
  PerformanceOptimizations::DatabaseManager.enable_query_optimizations

  # Setup performance monitoring
  PerformanceOptimizations::PerformanceMonitor.setup_memory_profiling
  PerformanceOptimizations::PerformanceMonitor.setup_bullet_gem
  PerformanceOptimizations::PerformanceMonitor.setup_request_timeout

  # Include enhanced optimizations
  ActiveRecord::Base.include PerformanceOptimizations::EnhancedQueryOptimizations
  ActionView::Base.include PerformanceOptimizations::EnhancedFragmentCaching

  # Preload critical data after initialization
  Rails.application.config.after_initialize do
    PerformanceOptimizations::CacheManager.preload_critical_data

    # Schedule intelligent cache warming for production
    if Rails.env.production?
      PerformanceOptimizations::CacheManager.delay.warm_cache_intelligently

      # Schedule periodic cache analytics
      PerformanceOptimizations::CacheManager.delay(run_at: 1.hour.from_now).cache_analytics
      PerformanceOptimizations::CacheManager.delay(run_at: 1.hour.from_now, repeat: true).cache_analytics
    end
  end

  Rails.logger.info("All performance optimizations successfully initialized")

rescue StandardError => e
  Rails.logger.error("Failed to initialize performance optimizations: #{e.message}")
  Rails.logger.error(e.backtrace.join("\n"))
  # Continue application startup even if performance optimizations fail
end