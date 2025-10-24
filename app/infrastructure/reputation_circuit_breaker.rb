# frozen_string_literal: true

# Circuit Breaker: Specialized for reputation system operations
# Provides fault tolerance and prevents cascade failures in reputation processing
class ReputationCircuitBreaker
  include Singleton
  include CircuitBreakerPattern

  # Circuit breaker configurations for different operation types
  CIRCUIT_CONFIGS = {
    reputation_calculation: {
      failure_threshold: 5,
      recovery_timeout: 30.seconds,
      expected_exceptions: [ActiveRecord::ConnectionTimeoutError, ActiveRecord::StatementInvalid]
    },
    reputation_storage: {
      failure_threshold: 3,
      recovery_timeout: 60.seconds,
      expected_exceptions: [ActiveRecord::ConnectionTimeoutError, ActiveRecord::StatementInvalid]
    },
    reputation_analytics: {
      failure_threshold: 7,
      recovery_timeout: 45.seconds,
      expected_exceptions: [ActiveRecord::ConnectionTimeoutError, Redis::TimeoutError]
    },
    external_api_calls: {
      failure_threshold: 3,
      recovery_timeout: 120.seconds,
      expected_exceptions: [Timeout::Error, Errno::ECONNREFUSED, ExternalApiError]
    }
  }.freeze

  def initialize
    @circuits = {}
    initialize_circuits
  end

  # Execute operation with reputation calculation circuit breaker
  def execute_calculation
    execute_with_circuit(:reputation_calculation) do
      yield
    end
  end

  # Execute operation with reputation storage circuit breaker
  def execute_storage
    execute_with_circuit(:reputation_storage) do
      yield
    end
  end

  # Execute operation with reputation analytics circuit breaker
  def execute_analytics
    execute_with_circuit(:reputation_analytics) do
      yield
    end
  end

  # Execute operation with external API circuit breaker
  def execute_external_api
    execute_with_circuit(:external_api_calls) do
      yield
    end
  end

  # Execute operation with custom circuit configuration
  def execute_with_custom_config(config_name, custom_config = {})
    config = CIRCUIT_CONFIGS[config_name].merge(custom_config)

    circuit_breaker = CircuitBreaker.new(
      failure_threshold: config[:failure_threshold],
      recovery_timeout: config[:recovery_timeout],
      expected_exception: config[:expected_exceptions]
    )

    circuit_breaker.execute do
      yield
    end
  end

  # Get circuit breaker status for monitoring
  def circuit_status
    @circuits.transform_values do |circuit|
      {
        state: circuit.state,
        failure_count: circuit.failure_count,
        last_failure_time: circuit.last_failure_time,
        next_retry_time: circuit.next_retry_time
      }
    end
  end

  # Reset all circuit breakers (admin operation)
  def reset_all_circuits
    @circuits.each_value(&:reset)
    Rails.logger.info('All reputation circuit breakers reset')
  end

  # Reset specific circuit breaker
  def reset_circuit(circuit_name)
    circuit = @circuits[circuit_name]
    return false unless circuit

    circuit.reset
    Rails.logger.info("Reputation circuit breaker #{circuit_name} reset")
    true
  end

  # Health check for all circuits
  def healthy?
    @circuits.values.all? { |circuit| circuit.state == :closed }
  end

  private

  def initialize_circuits
    CIRCUIT_CONFIGS.each do |name, config|
      @circuits[name] = CircuitBreaker.new(
        failure_threshold: config[:failure_threshold],
        recovery_timeout: config[:recovery_timeout],
        expected_exception: config[:expected_exceptions]
      )
    end
  end

  def execute_with_circuit(circuit_name)
    circuit = @circuits[circuit_name]

    unless circuit
      Rails.logger.error("Unknown circuit breaker: #{circuit_name}")
      return yield # Execute without circuit breaker
    end

    begin
      circuit.execute do
        yield
      end
    rescue CircuitBreaker::OpenCircuitError => e
      handle_open_circuit(circuit_name, e)
    rescue StandardError => e
      handle_circuit_error(circuit_name, e)
      raise
    end
  end

  def handle_open_circuit(circuit_name, error)
    Rails.logger.warn("Circuit breaker #{circuit_name} is OPEN: #{error.message}")

    # Send alert to monitoring
    MonitoringService.alert(
      service: 'ReputationCircuitBreaker',
      alert_type: :circuit_open,
      message: "Circuit breaker #{circuit_name} is open",
      metadata: { circuit_name: circuit_name }
    )

    # Return fallback response if available
    if block_given?
      begin
        yield # Try fallback block if provided
      rescue StandardError => fallback_error
        Rails.logger.error("Fallback also failed for #{circuit_name}: #{fallback_error.message}")
        raise error # Raise original circuit error
      end
    else
      raise error
    end
  end

  def handle_circuit_error(circuit_name, error)
    Rails.logger.error("Circuit breaker #{circuit_name} error: #{error.message}")

    # Record metrics for monitoring
    MetricsService.increment_counter(
      :reputation_circuit_breaker_failures,
      tags: { circuit_name: circuit_name, error_type: error.class.name }
    )
  end
end

# Enhanced Circuit Breaker implementation with additional features
class CircuitBreaker
  attr_reader :failure_threshold, :recovery_timeout, :expected_exception
  attr_accessor :failure_count, :last_failure_time, :state

  def initialize(failure_threshold: 5, recovery_timeout: 60.seconds, expected_exception: StandardError)
    @failure_threshold = failure_threshold
    @recovery_timeout = recovery_timeout
    @expected_exception = Array(expected_exception)
    @failure_count = 0
    @last_failure_time = nil
    @state = :closed
  end

  def execute
    case state
    when :open
      handle_open_state
    when :half_open
      handle_half_open_state { yield }
    else # :closed
      handle_closed_state { yield }
    end
  end

  def reset
    @failure_count = 0
    @last_failure_time = nil
    @state = :closed
  end

  private

  def handle_open_state
    if can_attempt_reset?
      @state = :half_open
      raise HalfOpenCircuitError.new(self)
    else
      raise OpenCircuitError.new(self)
    end
  end

  def handle_half_open_state
    begin
      result = yield

      # Success - reset and return result
      reset
      result
    rescue *@expected_exception => e
      # Failure - go back to open
      record_failure
      raise e
    end
  end

  def handle_closed_state
    begin
      result = yield

      # Success - reset failure count
      @failure_count = 0
      result
    rescue *@expected_exception => e
      # Failure - record and check threshold
      record_failure

      if should_open_circuit?
        @state = :open
        Rails.logger.warn("Circuit breaker opened after #{failure_count} failures")
      end

      raise e
    end
  end

  def can_attempt_reset?
    return false unless last_failure_time

    Time.current - last_failure_time >= recovery_timeout
  end

  def record_failure
    @failure_count += 1
    @last_failure_time = Time.current
  end

  def should_open_circuit?
    failure_count >= failure_threshold
  end

  def next_retry_time
    return nil unless last_failure_time

    last_failure_time + recovery_timeout
  end

  # Custom error classes
  class OpenCircuitError < StandardError
    attr_reader :circuit

    def initialize(circuit)
      @circuit = circuit
      super("Circuit breaker is OPEN")
    end
  end

  class HalfOpenCircuitError < StandardError
    attr_reader :circuit

    def initialize(circuit)
      @circuit = circuit
      super("Circuit breaker is HALF_OPEN")
    end
  end
end

# Resilience patterns for reputation operations
module ReputationResiliencePatterns
  # Retry pattern with exponential backoff
  def with_retry(max_retries = 3, base_delay = 1.second)
    attempt = 0

    begin
      attempt += 1
      yield
    rescue StandardError => e
      if attempt < max_retries && retryable_error?(e)
        delay = base_delay * (2 ** (attempt - 1)) + rand(0..1).seconds
        Rails.logger.warn("Retrying operation in #{delay.round(2)} seconds (attempt #{attempt}/#{max_retries})")
        sleep(delay)
        retry
      else
        raise e
      end
    end
  end

  # Fallback pattern
  def with_fallback(fallback_value = nil)
    begin
      yield
    rescue StandardError => e
      Rails.logger.warn("Operation failed, using fallback: #{e.message}")
      return fallback_value unless fallback_value.nil?

      # Try fallback block if provided
      if block_given?
        yield_fallback
      else
        raise e
      end
    end
  end

  # Timeout pattern
  def with_timeout(timeout_seconds = 30)
    Timeout::timeout(timeout_seconds) do
      yield
    end
  rescue Timeout::Error => e
    Rails.logger.error("Operation timed out after #{timeout_seconds} seconds")
    raise ReputationTimeoutError.new("Operation timed out after #{timeout_seconds} seconds")
  end

  # Bulkhead pattern for isolation
  def with_bulkhead(pool_size = 10)
    semaphore = Concurrent::Semaphore.new(pool_size)

    semaphore.acquire do
      yield
    end
  rescue Concurrent::Semaphore::SemaphoreLockedError => e
    raise ReputationResourceExhaustedError.new("Bulkhead pool exhausted (size: #{pool_size})")
  end

  private

  def retryable_error?(error)
    # Define which errors are retryable
    retryable_errors = [
      ActiveRecord::ConnectionTimeoutError,
      ActiveRecord::StatementInvalid,
      Redis::TimeoutError,
      Timeout::Error
    ]

    retryable_errors.any? { |error_class| error.is_a?(error_class) }
  end

  def yield_fallback
    # This would be implemented by the including class
    raise NotImplementedError, 'Fallback block must be provided'
  end

  # Custom error classes for resilience patterns
  class ReputationTimeoutError < StandardError; end
  class ReputationResourceExhaustedError < StandardError; end
end

# Reputation operation wrapper with resilience patterns
class ReputationOperationWrapper
  include ReputationResiliencePatterns

  def self.execute_calculation
    new.execute_with_resilience(:calculation) do
      yield
    end
  end

  def self.execute_storage
    new.execute_with_resilience(:storage) do
      yield
    end
  end

  def self.execute_analytics
    new.execute_with_resilience(:analytics) do
      yield
    end
  end

  def execute_with_resilience(operation_type)
    with_circuit_breaker(operation_type) do
      with_timeout do
        with_retry do
          yield
        end
      end
    end
  end

  private

  def with_circuit_breaker(operation_type)
    circuit_breaker = ReputationCircuitBreaker.instance

    case operation_type
    when :calculation
      circuit_breaker.execute_calculation { yield }
    when :storage
      circuit_breaker.execute_storage { yield }
    when :analytics
      circuit_breaker.execute_analytics { yield }
    else
      yield # No circuit breaker
    end
  end
end

# Monitoring and metrics for reputation circuit breakers
class ReputationCircuitBreakerMonitor
  include Singleton

  def initialize
    @metrics = {}
  end

  def record_circuit_event(circuit_name, event_type, metadata = {})
    metric_key = "reputation_circuit_#{circuit_name}_#{event_type}"

    @metrics[metric_key] ||= 0
    @metrics[metric_key] += 1

    # Send to monitoring service
    MonitoringService.record_metric(
      name: "reputation.circuit.#{circuit_name}.#{event_type}",
      value: 1,
      tags: metadata
    )
  end

  def get_circuit_metrics
    @metrics.dup
  end

  def reset_metrics
    @metrics.clear
  end
end