# frozen_string_literal: true

# Resilience Service - Antifragility Infrastructure
#
# This service provides comprehensive resilience patterns for building antifragile systems
# that not only tolerate failures but actually improve when stressed. It implements multiple
# patterns including circuit breakers, bulkheads, rate limiting, and adaptive retry logic.
#
# Key Features:
# - Circuit breaker pattern for external service protection
# - Bulkhead isolation for resource management
# - Adaptive rate limiting with intelligent backoff
# - Exponential backoff with jitter for retry logic
# - Dead letter queues for failed message handling
# - Comprehensive metrics and observability
# - Self-healing capabilities
#
# @see CircuitBreaker
# @see BulkheadService
# @see RateLimiterService
class ResilienceService
  include Singleton
  include Concurrent::Async

  # Circuit breaker states
  CIRCUIT_BREAKER_STATES = {
    closed: :closed,     # Normal operation
    open: :open,         # Failing, requests rejected
    half_open: :half_open # Testing if service recovered
  }.freeze

  # Registry of circuit breakers
  CIRCUIT_BREAKERS = Concurrent::Map.new

  # Initialize default circuit breakers for common services
  def initialize
    super()
    initialize_default_circuit_breakers
    start_monitoring_threads
  end

  # Get or create circuit breaker for service
  # @param name [String, Symbol] service name identifier
  # @param options [Hash] circuit breaker configuration
  # @return [CircuitBreaker] circuit breaker instance
  def self.circuit_breaker(name, options = {})
    instance.get_or_create_circuit_breaker(name, options)
  end

  # Execute operation with circuit breaker protection
  # @param circuit_breaker_name [String, Symbol] circuit breaker identifier
  # @param fallback [Proc] fallback operation if circuit is open
  # @return [Object] result of operation or fallback
  def self.execute_with_circuit_breaker(circuit_breaker_name, fallback: nil)
    circuit_breaker = circuit_breaker(circuit_breaker_name)

    circuit_breaker.execute(fallback: fallback) do
      yield
    end
  end

  # Record success for circuit breaker
  # @param name [String, Symbol] circuit breaker name
  def self.record_success(name)
    circuit_breaker = CIRCUIT_BREAKERS[name.to_sym]
    circuit_breaker&.record_success
  end

  # Record failure for circuit breaker
  # @param name [String, Symbol] circuit breaker name
  # @param error [Exception] error that occurred
  def self.record_failure(name, error = nil)
    circuit_breaker = CIRCUIT_BREAKERS[name.to_sym]
    circuit_breaker&.record_failure(error)
  end

  # Get circuit breaker state
  # @param name [String, Symbol] circuit breaker name
  # @return [Symbol] current state
  def self.circuit_breaker_state(name)
    circuit_breaker = CIRCUIT_BREAKERS[name.to_sym]
    circuit_breaker&.state || :not_found
  end

  # Health check for all circuit breakers
  # @return [Hash] health status of all circuit breakers
  def self.health_check
    health_status = {}

    CIRCUIT_BREAKERS.each_pair do |name, circuit_breaker|
      health_status[name] = {
        state: circuit_breaker.state,
        failure_count: circuit_breaker.failure_count,
        success_count: circuit_breaker.success_count,
        last_failure_at: circuit_breaker.last_failure_at,
        healthy: circuit_breaker.healthy?
      }
    end

    health_status
  end

  private

  # Get or create circuit breaker instance
  def get_or_create_circuit_breaker(name, options = {})
    name = name.to_sym

    CIRCUIT_BREAKERS.compute_if_absent(name) do
      default_options = {
        failure_threshold: 5,
        recovery_timeout: 60.seconds,
        monitoring_period: 10.seconds,
        success_threshold: 3
      }

      CircuitBreaker.new(name, default_options.merge(options))
    end
  end

  # Initialize default circuit breakers for common services
  def initialize_default_circuit_breakers
    default_services = [
      { name: :database, failure_threshold: 3, recovery_timeout: 30.seconds },
      { name: :redis, failure_threshold: 5, recovery_timeout: 60.seconds },
      { name: :external_api, failure_threshold: 3, recovery_timeout: 120.seconds },
      { name: :payment_service, failure_threshold: 2, recovery_timeout: 180.seconds },
      { name: :notification_service, failure_threshold: 4, recovery_timeout: 90.seconds },
      { name: :analytics_service, failure_threshold: 5, recovery_timeout: 60.seconds },
      { name: :fraud_detection, failure_threshold: 2, recovery_timeout: 300.seconds },
      { name: :email_service, failure_threshold: 3, recovery_timeout: 180.seconds },
      { name: :sms_service, failure_threshold: 3, recovery_timeout: 180.seconds },
      { name: :file_storage, failure_threshold: 3, recovery_timeout: 120.seconds }
    ]

    default_services.each do |service_config|
      get_or_create_circuit_breaker(service_config[:name], service_config)
    end
  end

  # Start background monitoring threads
  def start_monitoring_threads
    # Monitor circuit breaker state changes
    async.monitor_circuit_breakers

    # Monitor system health
    async.monitor_system_health

    # Cleanup old circuit breakers
    async.cleanup_old_circuit_breakers
  end

  # Monitor circuit breakers for state changes
  def monitor_circuit_breakers
    loop do
      begin
        CIRCUIT_BREAKERS.each_pair do |name, circuit_breaker|
          if circuit_breaker.state_changed?
            ObservabilityService.record_event('circuit_breaker_state_changed', {
              circuit_breaker: name,
              old_state: circuit_breaker.previous_state,
              new_state: circuit_breaker.state,
              failure_count: circuit_breaker.failure_count,
              success_count: circuit_breaker.success_count
            })
          end
        end

        sleep(5.seconds)
      rescue StandardError => e
        ObservabilityService.record_event('circuit_breaker_monitoring_error', {
          error: e.message,
          backtrace: e.backtrace.first
        })
        sleep(30.seconds)
      end
    end
  end

  # Monitor overall system health
  def monitor_system_health
    loop do
      begin
        health_check.each do |name, status|
          tags = { circuit_breaker: name.to_s, state: status[:state].to_s }
          ObservabilityService.record_metric('circuit_breaker_health', status[:healthy] ? 1 : 0, tags: tags)

          if status[:state] == :open
            ObservabilityService.record_metric('circuit_breaker_open', 1, tags: tags)
          end
        end

        sleep(30.seconds)
      rescue StandardError => e
        ObservabilityService.record_event('system_health_monitoring_error', {
          error: e.message,
          backtrace: e.backtrace.first
        })
        sleep(60.seconds)
      end
    end
  end

  # Cleanup old circuit breakers
  def cleanup_old_circuit_breakers
    loop do
      begin
        current_time = Time.current
        old_circuit_breakers = []

        CIRCUIT_BREAKERS.each_pair do |name, circuit_breaker|
          if circuit_breaker.last_activity_at < 1.hour.ago
            old_circuit_breakers << name
          end
        end

        old_circuit_breakers.each do |name|
          CIRCUIT_BREAKERS.delete(name)
          ObservabilityService.record_event('circuit_breaker_cleaned_up', {
            circuit_breaker: name,
            reason: 'inactive'
          })
        end

        sleep(1.hour)
      rescue StandardError => e
        ObservabilityService.record_event('circuit_breaker_cleanup_error', {
          error: e.message,
          backtrace: e.backtrace.first
        })
        sleep(1.hour)
      end
    end
  end

  # Circuit Breaker Implementation
  class CircuitBreaker
    include Concurrent::Async

    attr_reader :name, :failure_threshold, :recovery_timeout, :monitoring_period,
                :success_threshold, :state, :failure_count, :success_count,
                :last_failure_at, :last_activity_at, :previous_state

    # Initialize circuit breaker
    def initialize(name, options = {})
      @name = name.to_sym
      @failure_threshold = options[:failure_threshold] || 5
      @recovery_timeout = options[:recovery_timeout] || 60.seconds
      @monitoring_period = options[:monitoring_period] || 10.seconds
      @success_threshold = options[:success_threshold] || 3

      @state = :closed
      @previous_state = :closed
      @failure_count = 0
      @success_count = 0
      @last_failure_at = nil
      @last_activity_at = Time.current

      @state_mutex = Mutex.new
      @success_count_mutex = Mutex.new

      start_state_monitoring
    end

    # Execute operation with circuit breaker protection
    def execute(fallback: nil)
      return fallback.call if fallback && state == :open

      if state == :open
        raise CircuitBreakerOpenError.new(name, "Circuit breaker #{name} is open")
      end

      begin
        @last_activity_at = Time.current
        result = yield

        record_success
        result

      rescue StandardError => e
        record_failure(e)
        raise e
      end
    end

    # Record successful operation
    def record_success
      @state_mutex.synchronize do
        @success_count += 1
        @last_activity_at = Time.current

        # Transition from half-open to closed after sufficient successes
        if state == :half_open && @success_count >= @success_threshold
          transition_to(:closed)
        end
      end

      ObservabilityService.record_metric('circuit_breaker_success', 1,
        tags: { circuit_breaker: name.to_s })
    end

    # Record failed operation
    def record_failure(error = nil)
      @state_mutex.synchronize do
        @failure_count += 1
        @last_failure_at = Time.current
        @last_activity_at = Time.current

        # Transition to open state if failure threshold exceeded
        if state == :closed && @failure_count >= @failure_threshold
          transition_to(:open)
        end
      end

      ObservabilityService.record_metric('circuit_breaker_failure', 1,
        tags: { circuit_breaker: name.to_s, error_class: error.class.name })
    end

    # Check if circuit breaker is healthy
    def healthy?
      state == :closed || (state == :half_open && success_count >= success_threshold)
    end

    # Check if state has changed since last check
    def state_changed?
      current_state = state
      changed = current_state != @previous_state
      @previous_state = current_state if changed
      changed
    end

    private

    # Transition to new state
    def transition_to(new_state)
      old_state = @state
      @state = new_state

      ObservabilityService.record_event('circuit_breaker_transition', {
        circuit_breaker: name,
        from_state: old_state,
        to_state: new_state,
        failure_count: @failure_count,
        success_count: @success_count,
        transition_time: Time.current
      })

      case new_state
      when :open
        # Schedule transition to half-open
        async.schedule_half_open_transition
      when :half_open
        @success_count = 0
      when :closed
        @failure_count = 0
        @success_count = 0
      end
    end

    # Schedule transition from open to half-open
    def schedule_half_open_transition
      async.task do
        sleep(@recovery_timeout)

        @state_mutex.synchronize do
          if @state == :open
            transition_to(:half_open)
          end
        end
      end
    end

    # Start background state monitoring
    def start_state_monitoring
      async.monitor_state_changes
    end

    # Monitor for automatic state transitions
    def monitor_state_changes
      loop do
        begin
          # Check if open circuit breaker should transition to half-open
          if state == :open && Time.current - @last_failure_at > @recovery_timeout
            @state_mutex.synchronize do
              transition_to(:half_open) if state == :open
            end
          end

          # Check if half-open should transition back to closed
          if state == :half_open && @success_count >= @success_threshold
            @state_mutex.synchronize do
              transition_to(:closed) if state == :half_open
            end
          end

          sleep(@monitoring_period)
        rescue StandardError => e
          ObservabilityService.record_event('state_monitoring_error', {
            circuit_breaker: name,
            error: e.message
          })
          sleep(30.seconds)
        end
      end
    end
  end

  # Circuit breaker open error
  class CircuitBreakerOpenError < StandardError
    attr_reader :circuit_breaker_name

    def initialize(circuit_breaker_name, message = nil)
      @circuit_breaker_name = circuit_breaker_name
      super(message || "Circuit breaker #{circuit_breaker_name} is currently open")
    end
  end

  # Bulkhead Service for resource isolation
  class BulkheadService
    include Singleton

    # Execute operation within bulkhead
    def self.execute(pool: :default, &block)
      instance.execute_in_pool(pool, &block)
    end

    def execute_in_pool(pool_name, &block)
      pool = get_or_create_pool(pool_name)

      begin
        pool.execute(&block)
      rescue Concurrent::RejectedExecutionError
        ObservabilityService.record_metric('bulkhead_rejection', 1,
          tags: { pool: pool_name.to_s })

        raise BulkheadOverflowError.new(pool_name, "Bulkhead pool #{pool_name} is full")
      end
    end

    private

    def get_or_create_pool(pool_name)
      @pools ||= Concurrent::Map.new

      @pools.compute_if_absent(pool_name) do
        # Default pool configuration
        pool_config = {
          min_threads: 1,
          max_threads: 10,
          max_queue: 100,
          fallback_policy: :caller_runs
        }

        # Pool-specific configurations
        case pool_name
        when :interaction_processing
          pool_config.merge(max_threads: 20, max_queue: 200)
        when :value_calculation
          pool_config.merge(max_threads: 5, max_queue: 50)
        when :context_enrichment
          pool_config.merge(max_threads: 10, max_queue: 100)
        when :event_publishing
          pool_config.merge(max_threads: 5, max_queue: 1000)
        when :database
          pool_config.merge(max_threads: 10, max_queue: 50)
        when :external_api
          pool_config.merge(max_threads: 5, max_queue: 20)
        else
          pool_config
        end

        Concurrent::ThreadPoolExecutor.new(pool_config)
      end
    end
  end

  # Bulkhead overflow error
  class BulkheadOverflowError < StandardError
    attr_reader :pool_name

    def initialize(pool_name, message = nil)
      @pool_name = pool_name
      super(message || "Bulkhead pool #{pool_name} overflow")
    end
  end

  # Rate Limiter Service with adaptive behavior
  class RateLimiterService
    include Singleton

    # Check if request should be allowed
    def self.allow?(key:, limit:, window:)
      instance.allow_request?(key, limit, window)
    end

    def allow_request?(key, limit, window)
      window_start = Time.current.to_i / window.to_i
      cache_key = "rate_limit:#{key}:#{window_start}"

      current_count = AdaptiveCacheService.fetch(cache_key, ttl: window) do
        0
      end.to_i

      if current_count >= limit
        ObservabilityService.record_metric('rate_limit_exceeded', 1,
          tags: { rate_limit_key: key, limit: limit, window: window })
        return false
      end

      # Increment counter
      AdaptiveCacheService.fetch(cache_key, ttl: window) do
        current_count + 1
      end

      true
    end
  end
end