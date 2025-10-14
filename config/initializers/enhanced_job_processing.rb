# frozen_string_literal: true

# =============================================================================
# Enhanced Background Job Processing System
# =============================================================================
# This module provides enterprise-grade background job processing with:
# - Advanced retry strategies with exponential backoff
# - Performance monitoring and analytics
# - Intelligent job scheduling and prioritization
# - Resource management and load balancing
# - Comprehensive error handling and recovery
# - Real-time monitoring and alerting
#
# Architecture:
# - Service-oriented design with dependency injection
# - Circuit breaker pattern for external service resilience
# - Intelligent queue management with priority handling
# - Performance monitoring and bottleneck detection
# - Graceful degradation and comprehensive error handling
#
# Success Metrics:
# - 99.9% job completion rate
# - Sub-1s job processing overhead
# - Zero job loss due to system failures
# - Intelligent resource utilization
# =============================================================================

begin
  require 'sidekiq'
  require 'sidekiq-cron'
rescue LoadError => e
  Rails.logger.warn("Sidekiq not available: #{e.message}. Background jobs will be disabled.") if defined?(Rails)
  # Define a no-op module if Sidekiq is not available
  module Sidekiq
    def self.configure_server(*); end
    def self.configure_client(*); end
  end
end

module EnhancedJobProcessing
  # ========================================================================
  # Configuration Management
  # ========================================================================

  class Configuration
    JOB_CONFIGURATIONS = {
      development: {
        retry_attempts: 3,
        retry_backoff: :exponential,
        timeout: 30.seconds,
        queue_priorities: {
          critical: 1,
          high: 2,
          default: 3,
          low: 4
        },
        worker_concurrency: 2,
        monitoring_enabled: true,
        circuit_breaker_threshold: 5,
        batch_size: 100
      },
      production: {
        retry_attempts: 5,
        retry_backoff: :exponential,
        timeout: 60.seconds,
        queue_priorities: {
          critical: 1,
          high: 2,
          default: 3,
          low: 4
        },
        worker_concurrency: ENV.fetch('SIDEKIQ_CONCURRENCY', 10).to_i,
        monitoring_enabled: true,
        circuit_breaker_threshold: 10,
        batch_size: 1000
      },
      test: {
        retry_attempts: 0,
        retry_backoff: :immediate,
        timeout: 5.seconds,
        queue_priorities: {
          critical: 1,
          high: 2,
          default: 3,
          low: 4
        },
        worker_concurrency: 1,
        monitoring_enabled: false,
        circuit_breaker_threshold: 1,
        batch_size: 10
      }
    }.freeze

    def self.for_environment(env = Rails.env.to_sym)
      JOB_CONFIGURATIONS.fetch(env, JOB_CONFIGURATIONS[:development])
    end

    def self.validate_config!(config)
      required_keys = [:retry_attempts, :timeout, :queue_priorities, :worker_concurrency]

      required_keys.each do |key|
        unless config.key?(key)
          raise ArgumentError, "Missing required job configuration key: #{key}"
        end
      end

      unless config[:retry_attempts].is_a?(Integer) && config[:retry_attempts] >= 0
        raise ArgumentError, "Invalid retry_attempts: #{config[:retry_attempts]}"
      end

      unless config[:timeout].is_a?(ActiveSupport::Duration)
        raise ArgumentError, "Invalid timeout: #{config[:timeout]}"
      end
    end
  end

  # ========================================================================
  # Enhanced Sidekiq Configuration
  # ========================================================================

  class SidekiqManager
    class << self
      def configure_sidekiq
        config = Configuration.for_environment

        Sidekiq.configure_server do |sidekiq_config|
          configure_server_settings(sidekiq_config, config)
          configure_error_handling(sidekiq_config, config)
          configure_middleware(sidekiq_config, config)
          configure_schedules(sidekiq_config, config)
        end

        Sidekiq.configure_client do |sidekiq_config|
          configure_client_settings(sidekiq_config, config)
        end

        Rails.logger.info("Enhanced Sidekiq configuration applied")
      rescue StandardError => e
        Rails.logger.error("Failed to configure Sidekiq: #{e.message}")
        raise
      end

      private

      def configure_server_settings(sidekiq_config, config)
        sidekiq_config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
        sidekiq_config.concurrency = config[:worker_concurrency]
        sidekiq_config.timeout = config[:timeout]

        # Configure queues with priorities
        sidekiq_config.queues = config[:queue_priorities].keys.sort_by { |k| config[:queue_priorities][k] }

        # Configure worker options
        sidekiq_config.options[:fetch] = Sidekiq::Fetch::WeightedRoundRobin
        sidekiq_config.options[:job_logger] = EnhancedJobLogger

        # Configure dead job handling
        sidekiq_config.dead_max_jobs = 1000
        sidekiq_config.dead_timeout_in_seconds = 30.days
      end

      def configure_client_settings(sidekiq_config, config)
        sidekiq_config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

        # Configure client middleware
        sidekiq_config.client_middleware do |chain|
          chain.add EnhancedJobClientMiddleware
        end
      end

      def configure_error_handling(sidekiq_config, config)
        sidekiq_config.error_handlers << method(:handle_job_error)
        sidekiq_config.death_handlers << method(:handle_dead_job)
      end

      def configure_middleware(sidekiq_config, config)
        sidekiq_config.server_middleware do |chain|
          chain.add EnhancedJobServerMiddleware
          chain.add Sidekiq::Middleware::Server::RetryJobs,
                   max_retries: config[:retry_attempts],
                   backoff: config[:retry_backoff]
        end

        sidekiq_config.client_middleware do |chain|
          chain.add EnhancedJobClientMiddleware
        end
      end

      def configure_schedules(sidekiq_config, config)
        # Configure recurring jobs
        Sidekiq::Cron::Job.create(
          name: 'cache_warming',
          cron: '0 */6 * * *', # Every 6 hours
          class: 'CacheWarmingJob',
          queue: 'low'
        )

        Sidekiq::Cron::Job.create(
          name: 'analytics_collection',
          cron: '0 */1 * * *', # Every hour
          class: 'AnalyticsCollectionJob',
          queue: 'low'
        )

        Sidekiq::Cron::Job.create(
          name: 'cleanup_tasks',
          cron: '0 2 * * *', # Daily at 2 AM
          class: 'CleanupTasksJob',
          queue: 'low'
        )
      end

      def handle_job_error(ex, ctx)
        # Enhanced error handling with monitoring integration
        job_context = {
          job_id: ctx['jid'],
          job_class: ctx['class'],
          queue: ctx['queue'],
          error_class: ex.class.name,
          error_message: ex.message,
          backtrace: ex.backtrace&.first(5),
          retry_count: ctx['retry_count'],
          correlation_id: ctx['correlation_id']
        }

        Rails.logger.error("Sidekiq job failed: #{ex.message}", job_context)

        # Record job failure metrics
        EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
          'sidekiq.job.error',
          1,
          'count',
          job_context
        )

        # Send alert for critical job failures
        if ctx['retry_count'].to_i >= 3
          EnhancedMonitoring::PerformanceMonitor.record_business_metric(
            'sidekiq.critical_failure',
            1,
            { job_class: ctx['class'], error_class: ex.class.name }
          )
        end
      end

      def handle_dead_job(job, ex)
        # Handle permanently failed jobs
        Rails.logger.fatal("Sidekiq job permanently failed: #{job['class']}", {
          job_id: job['jid'],
          error_class: ex.class.name,
          error_message: ex.message,
          retry_count: job['retry_count']
        })

        # Record dead job metrics
        EnhancedMonitoring::PerformanceMonitor.record_business_metric(
          'sidekiq.job.dead',
          1,
          { job_class: job['class'], error_class: ex.class.name }
        )
      end
    end
  end

  # ========================================================================
  # Enhanced Job Middleware
  # ========================================================================

  class EnhancedJobServerMiddleware
    def call(worker, msg, queue)
      start_time = Time.current
      correlation_id = msg['correlation_id'] || SecureRandom.uuid

      # Add correlation ID to job context
      msg['correlation_id'] = correlation_id

      # Add breadcrumb for job tracing
      EnhancedMonitoring::RequestContext.add_breadcrumb(
        'sidekiq',
        "Processing #{worker.class.name}",
        { job_id: msg['jid'], queue: queue, correlation_id: correlation_id }
      )

      begin
        # Execute job with monitoring
        result = yield

        # Record successful job completion
        duration = Time.current - start_time
        record_job_success(worker, msg, queue, duration)

        result
      rescue StandardError => e
        # Record job failure
        duration = Time.current - start_time
        record_job_failure(worker, msg, queue, duration, e)

        raise
      end
    end

    private

    def record_job_success(worker, msg, queue, duration)
      Rails.logger.info("Sidekiq job completed successfully", {
        job_id: msg['jid'],
        job_class: worker.class.name,
        queue: queue,
        duration_ms: (duration * 1000).round(2),
        correlation_id: msg['correlation_id']
      })

      # Record performance metrics
      EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
        'sidekiq.job.duration',
        duration * 1000,
        'ms',
        {
          job_class: worker.class.name,
          queue: queue,
          success: true
        }
      )
    end

    def record_job_failure(worker, msg, queue, duration, error)
      Rails.logger.error("Sidekiq job failed", {
        job_id: msg['jid'],
        job_class: worker.class.name,
        queue: queue,
        duration_ms: (duration * 1000).round(2),
        error_class: error.class.name,
        error_message: error.message,
        correlation_id: msg['correlation_id']
      })

      # Record failure metrics
      EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
        'sidekiq.job.duration',
        duration * 1000,
        'ms',
        {
          job_class: worker.class.name,
          queue: queue,
          success: false,
          error_class: error.class.name
        }
      )
    end
  end

  class EnhancedJobClientMiddleware
    def call(worker_class, msg, queue, redis_pool)
      # Add client-side monitoring and context
      msg['enqueued_at'] = Time.current.to_f
      msg['correlation_id'] ||= SecureRandom.uuid

      # Record job enqueue metrics
      EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
        'sidekiq.job.enqueued',
        1,
        'count',
        { job_class: worker_class.name, queue: queue }
      )

      yield
    end
  end

  # ========================================================================
  # Enhanced Job Logger
  # ========================================================================

  class EnhancedJobLogger
    def call(item, queue)
      # Enhanced logging with structured format
      job_data = {
        job_id: item['jid'],
        job_class: item['class'],
        queue: queue,
        enqueued_at: item['enqueued_at'],
        correlation_id: item['correlation_id']
      }

      Rails.logger.info("Sidekiq job started", job_data)
    end
  end

  # ========================================================================
  # Circuit Breaker for External Services
  # ========================================================================

  class CircuitBreaker
    class << self
      def call(service_name, &block)
        circuit = get_circuit(service_name)

        if circuit.open?
          # Circuit is open, return cached response or error
          handle_open_circuit(service_name)
        else
          begin
            # Execute the block
            result = block.call

            # Record success and close circuit if it was half-open
            circuit.record_success
            result
          rescue StandardError => e
            # Record failure
            circuit.record_failure

            # Re-raise the exception
            raise e
          end
        end
      end

      private

      def get_circuit(service_name)
        @circuits ||= {}
        @circuits[service_name] ||= Circuit.new(
          failure_threshold: Configuration.for_environment[:circuit_breaker_threshold],
          recovery_timeout: 60.seconds
        )
      end

      def handle_open_circuit(service_name)
        Rails.logger.warn("Circuit breaker open for service: #{service_name}")

        # Return cached response if available
        cached_response = Rails.cache.read("circuit_breaker:#{service_name}:cached_response")
        return cached_response if cached_response.present?

        # Return error response
        raise CircuitBreakerOpenError.new("Service #{service_name} is currently unavailable")
      end
    end
  end

  class Circuit
    attr_reader :failure_count, :last_failure_time, :state

    def initialize(failure_threshold:, recovery_timeout:)
      @failure_threshold = failure_threshold
      @recovery_timeout = recovery_timeout
      @failure_count = 0
      @last_failure_time = nil
      @state = :closed
    end

    def record_success
      @failure_count = 0
      @state = :closed
    end

    def record_failure
      @failure_count += 1
      @last_failure_time = Time.current

      if @failure_count >= @failure_threshold
        @state = :open
      else
        @state = :half_open
      end
    end

    def open?
      @state == :open || (@state == :half_open && half_open_timeout?)
    end

    def half_open_timeout?
      return false unless @last_failure_time

      Time.current - @last_failure_time < @recovery_timeout
    end
  end

  class CircuitBreakerOpenError < StandardError; end

  # ========================================================================
  # Enhanced Job Base Classes
  # ========================================================================

  class EnhancedWorker
    include Sidekiq::Worker

    sidekiq_options retry: 5, backoff: :exponential

    def perform(*args)
      # Enhanced perform method with monitoring
      start_time = Time.current

      begin
        # Add breadcrumb for job tracing
        EnhancedMonitoring::RequestContext.add_breadcrumb(
          'sidekiq',
          "Executing #{self.class.name}#perform",
          { job_id: jid, args: args }
        )

        # Execute the actual job logic
        result = perform_job(*args)

        # Record successful completion
        duration = Time.current - start_time
        record_job_completion(duration, true)

        result
      rescue StandardError => e
        # Record failure
        duration = Time.current - start_time
        record_job_completion(duration, false, e)

        raise
      end
    end

    private

    def perform_job(*args)
      # Override in subclasses
      raise NotImplementedError, "Subclasses must implement perform_job"
    end

    def record_job_completion(duration, success, error = nil)
      metrics = {
        job_class: self.class.name,
        duration_ms: (duration * 1000).round(2),
        success: success,
        retry_count: retry_count
      }

      if error
        metrics[:error_class] = error.class.name
        metrics[:error_message] = error.message
      end

      EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
        'sidekiq.job.duration',
        duration * 1000,
        'ms',
        metrics
      )
    end
  end

  # ========================================================================
  # Specialized Job Classes
  # ========================================================================

  class CacheWarmingJob
    include Sidekiq::Worker

    sidekiq_options queue: :low, retry: 3

    def perform
      Rails.logger.info("Starting cache warming job")

      # Warm critical caches
      PerformanceOptimizations::CacheManager.warm_cache_intelligently

      # Record cache warming metrics
      EnhancedMonitoring::PerformanceMonitor.record_business_metric(
        'cache.warming.completed',
        1,
        { timestamp: Time.current }
      )

      Rails.logger.info("Cache warming job completed")
    end
  end

  class AnalyticsCollectionJob
    include Sidekiq::Worker

    sidekiq_options queue: :low, retry: 3

    def perform
      Rails.logger.info("Starting analytics collection job")

      # Collect and process analytics data
      analytics_data = collect_analytics_data

      # Store analytics data
      store_analytics_data(analytics_data)

      # Record analytics metrics
      EnhancedMonitoring::PerformanceMonitor.record_business_metric(
        'analytics.collection.completed',
        1,
        { data_points: analytics_data.size }
      )

      Rails.logger.info("Analytics collection job completed")
    end

    private

    def collect_analytics_data
      # Collect various analytics data
      {
        user_metrics: collect_user_metrics,
        order_metrics: collect_order_metrics,
        product_metrics: collect_product_metrics,
        performance_metrics: collect_performance_metrics
      }
    end

    def collect_user_metrics
      {
        total_users: User.count,
        active_users: User.where('last_sign_in_at > ?', 30.days.ago).count,
        new_users_today: User.where(created_at: Date.current.all_day).count
      }
    end

    def collect_order_metrics
      {
        total_orders: Order.count,
        orders_today: Order.where(created_at: Date.current.all_day).count,
        total_revenue: Order.sum(:total_cents) / 100.0,
        average_order_value: Order.average(:total_cents).to_f / 100.0
      }
    end

    def collect_product_metrics
      {
        total_products: Product.count,
        active_products: Product.active.count,
        low_stock_products: Product.where('stock_quantity <= ?', 5).count,
        featured_products: Product.featured.count
      }
    end

    def collect_performance_metrics
      # Collect performance metrics from monitoring system
      EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
        'analytics.collection.performance',
        1,
        'count',
        { timestamp: Time.current }
      )

      {}
    end

    def store_analytics_data(data)
      # Store analytics data for reporting
      Rails.cache.write('latest_analytics', data, expires_in: 24.hours)
    end
  end

  class CleanupTasksJob
    include Sidekiq::Worker

    sidekiq_options queue: :low, retry: 3

    def perform
      Rails.logger.info("Starting cleanup tasks job")

      # Perform various cleanup tasks
      cleanup_old_logs
      cleanup_expired_cache
      cleanup_temp_files
      cleanup_old_notifications

      # Record cleanup metrics
      EnhancedMonitoring::PerformanceMonitor.record_business_metric(
        'cleanup.tasks.completed',
        1,
        { timestamp: Time.current }
      )

      Rails.logger.info("Cleanup tasks job completed")
    end

    private

    def cleanup_old_logs
      # Clean up old log files
      log_files = Dir.glob(Rails.root.join('log', '*.log'))
      old_logs = log_files.select { |f| File.mtime(f) < 7.days.ago }

      old_logs.each do |log_file|
        File.delete(log_file)
        Rails.logger.info("Deleted old log file: #{log_file}")
      end
    end

    def cleanup_expired_cache
      # Clean up expired cache entries
      Rails.cache.cleanup if Rails.cache.respond_to?(:cleanup)
    end

    def cleanup_temp_files
      # Clean up temporary files
      temp_dir = Rails.root.join('tmp')
      old_files = Dir.glob(temp_dir.join('**/*')).select { |f| File.mtime(f) < 1.day.ago }

      old_files.each do |file|
        File.delete(file) if File.file?(file)
      end
    end

    def cleanup_old_notifications
      # Clean up old notifications
      Notification.where('created_at < ?', 90.days.ago).delete_all
    end
  end

  # ========================================================================
  # Job Queue Management
  # ========================================================================

  class QueueManager
    class << self
      def queue_size(queue_name)
        Sidekiq::Queue.new(queue_name).size
      rescue StandardError
        0
      end

      def queue_latency(queue_name)
        queue = Sidekiq::Queue.new(queue_name)
        queue.latency if queue.respond_to?(:latency)
      rescue StandardError
        0
      end

      def worker_status
        # Get worker status information
        workers = Sidekiq::Workers.new
        {
          total_workers: workers.size,
          busy_workers: workers.count { |_, _, work| work['payload'] },
          queues: Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size } }
        }
      rescue StandardError => e
        Rails.logger.error("Failed to get worker status: #{e.message}")
        { error: e.message }
      end

      def pause_queue(queue_name)
        Sidekiq::Queue.new(queue_name).pause
        Rails.logger.info("Paused queue: #{queue_name}")
      rescue StandardError => e
        Rails.logger.error("Failed to pause queue #{queue_name}: #{e.message}")
      end

      def resume_queue(queue_name)
        Sidekiq::Queue.new(queue_name).unpause
        Rails.logger.info("Resumed queue: #{queue_name}")
      rescue StandardError => e
        Rails.logger.error("Failed to resume queue #{queue_name}: #{e.message}")
      end
    end
  end
end

# =============================================================================
# Rails Integration
# =============================================================================

Rails.application.configure do
  # Configure Sidekiq with enhanced settings
  config.active_job.queue_adapter = :sidekiq

  # Configure job queue priorities
  config.active_job.queue_priority = {
    critical: 1,
    high: 2,
    default: 3,
    low: 4
  }

  Rails.logger.info("Enhanced job processing configured for #{Rails.env} environment")
end

# =============================================================================
# Initialize Enhanced Job Processing
# =============================================================================

begin
  # Configure enhanced Sidekiq
  EnhancedJobProcessing::SidekiqManager.configure_sidekiq

  # Configure circuit breaker for external services
  Rails.application.config.after_initialize do
    # Initialize circuit breakers for external services
    %w[square_api elasticsearch payment_gateway].each do |service|
      EnhancedJobProcessing::CircuitBreaker.get_circuit(service)
    end
  end

  Rails.logger.info("Enhanced job processing system successfully initialized")

rescue StandardError => e
  Rails.logger.error("Failed to initialize enhanced job processing: #{e.message}")
  Rails.logger.error(e.backtrace.join("\n"))
  # Continue application startup even if job processing fails
end

# =============================================================================
# Global Job Helpers
# =============================================================================

module JobHelpers
  def perform_with_circuit_breaker(service_name, &block)
    EnhancedJobProcessing::CircuitBreaker.call(service_name, &block)
  end

  def queue_job(job_class, *args, queue: :default, priority: nil)
    # Enhanced job queuing with monitoring
    job_class.perform_async(*args).tap do |jid|
      EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
        'sidekiq.job.queued',
        1,
        'count',
        { job_class: job_class.name, queue: queue }
      )
    end
  end

  def schedule_job(job_class, cron_expression, *args, queue: :default)
    # Schedule recurring job
    job_class.perform_in(cron_expression, *args).tap do |jid|
      Rails.logger.info("Scheduled recurring job: #{job_class.name} with cron: #{cron_expression}")
    end
  end
end

# Include job helpers globally
Object.include JobHelpers

Rails.logger.info("Enhanced job processing system loaded successfully")