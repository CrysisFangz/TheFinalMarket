# frozen_string_literal: true

# Circuit Breaker implementation for fault tolerance
# Prevents cascade failures and implements graceful degradation
class CircuitBreaker
  # Circuit breaker states
  STATES = {
    closed: 'closed',     # Normal operation
    open: 'open',         # Failing, requests rejected
    half_open: 'half_open' # Testing if service recovered
  }.freeze

  # Circuit breaker configuration
  CircuitBreakerConfig = Struct.new(
    :failure_threshold,    # Number of failures to open circuit
    :recovery_timeout,     # Seconds to wait before half-open
    :success_threshold,    # Successes needed in half-open to close
    :timeout_seconds,      # Request timeout
    keyword_init: true
  )

  # Default configuration values
  DEFAULT_CONFIG = CircuitBreakerConfig.new(
    failure_threshold: 5,
    recovery_timeout: 60,
    success_threshold: 3,
    timeout_seconds: 30
  ).freeze

  attr_reader :name, :state, :config, :failure_count, :success_count,
              :last_failure_time, :last_success_time

  # Initialize circuit breaker
  # @param name [String] circuit breaker name for monitoring
  # @param config [CircuitBreakerConfig] configuration options
  def initialize(name, config = nil)
    @name = name
    @config = config || DEFAULT_CONFIG
    @state = :closed
    @failure_count = 0
    @success_count = 0
    @last_failure_time = nil
    @last_success_time = Time.current
    @mutex = Mutex.new
  end

  # Execute operation with circuit breaker protection
  # @param operation [Proc] operation to execute
  # @return [Object] operation result
  # @raise [CircuitBreakerOpenError] if circuit is open
  def execute(&operation)
    @mutex.synchronize do
      check_and_transition_state

      if @state == :open
        raise CircuitBreakerOpenError.new(@name, time_to_next_attempt)
      end

      begin
        result = execute_with_timeout(&operation)

        record_success
        result
      rescue StandardError => e
        record_failure
        raise e
      end
    end
  end

  # Check if circuit breaker allows requests
  # @return [Boolean] true if requests allowed
  def allows_requests?
    @mutex.synchronize do
      check_and_transition_state
      @state != :open
    end
  end

  # Get circuit breaker metrics
  # @return [Hash] current metrics
  def metrics
    @mutex.synchronize do
      {
        name: @name,
        state: @state,
        failure_count: @failure_count,
        success_count: @success_count,
        last_failure_time: @last_failure_time,
        last_success_time: @last_success_time,
        uptime_percentage: calculate_uptime_percentage
      }
    end
  end

  # Force circuit breaker to open state (for testing or manual intervention)
  def trip
    @mutex.synchronize do
      @state = :open
      @failure_count += 1
      @last_failure_time = Time.current
    end
  end

  # Force circuit breaker to closed state (for testing or manual intervention)
  def reset
    @mutex.synchronize do
      @state = :closed
      @failure_count = 0
      @success_count = 0
      @last_failure_time = nil
      @last_success_time = Time.current
    end
  end

  private

  # Check current state and transition if needed
  def check_and_transition_state
    case @state
    when :closed
      # Check if we should open due to failures
      if should_open?
        open_circuit
      end
    when :open
      # Check if we should try half-open
      if should_attempt_reset?
        @state = :half_open
        @success_count = 0
      end
    when :half_open
      # Check if we should close or re-open
      if @failure_count > 0
        open_circuit
      elsif @success_count >= @config.success_threshold
        close_circuit
      end
    end
  end

  # Check if circuit should open due to failures
  # @return [Boolean] true if should open
  def should_open?
    @failure_count >= @config.failure_threshold
  end

  # Check if circuit should attempt reset
  # @return [Boolean] true if should attempt reset
  def should_attempt_reset?
    return false unless @last_failure_time

    Time.current - @last_failure_time >= @config.recovery_timeout
  end

  # Open the circuit breaker
  def open_circuit
    @state = :open
    @last_failure_time = Time.current

    # Log circuit breaker event
    Rails.logger.warn(
      "Circuit breaker '#{@name}' opened after #{@failure_count} failures"
    )

    # Publish circuit breaker event for monitoring
    publish_circuit_breaker_event(:opened)
  end

  # Close the circuit breaker
  def close_circuit
    @state = :closed
    @failure_count = 0
    @last_success_time = Time.current

    Rails.logger.info("Circuit breaker '#{@name}' closed after #{@success_count} successes")

    publish_circuit_breaker_event(:closed)
  end

  # Record successful operation
  def record_success
    @success_count += 1
    @last_success_time = Time.current

    Rails.logger.debug("Circuit breaker '#{@name}' recorded success (#{@success_count})")
  end

  # Record failed operation
  def record_failure
    @failure_count += 1
    @last_failure_time = Time.current

    Rails.logger.warn("Circuit breaker '#{@name}' recorded failure (#{@failure_count})")
  end

  # Execute operation with timeout
  # @param operation [Proc] operation to execute
  # @return [Object] operation result
  def execute_with_timeout(&operation)
    Timeout::timeout(@config.timeout_seconds) do
      operation.call
    end
  end

  # Calculate uptime percentage
  # @return [Float] uptime percentage
  def calculate_uptime_percentage
    return 100.0 if @failure_count.zero?

    total_operations = @success_count + @failure_count
    (@success_count.to_f / total_operations) * 100
  end

  # Get time until next retry attempt
  # @return [Integer] seconds until next attempt
  def time_to_next_attempt
    return 0 unless @last_failure_time

    elapsed = Time.current - @last_failure_time
    remaining = @config.recovery_timeout - elapsed.to_i

    [remaining, 0].max
  end

  # Publish circuit breaker state change event
  # @param state [Symbol] new state
  def publish_circuit_breaker_event(state)
    # This would publish to monitoring system
    Rails.logger.info("Circuit breaker '#{@name}' transitioned to #{state} state")

    # In a real implementation, this would:
    # 1. Send metrics to monitoring system (DataDog, New Relic, etc.)
    # 2. Trigger alerts if needed
    # 3. Update dashboards
  end

  # Circuit breaker open error
  class CircuitBreakerOpenError < StandardError
    attr_reader :circuit_name, :retry_after_seconds

    # Initialize error
    # @param circuit_name [String] name of circuit breaker
    # @param retry_after_seconds [Integer] seconds until retry
    def initialize(circuit_name, retry_after_seconds)
      @circuit_name = circuit_name
      @retry_after_seconds = retry_after_seconds

      super("Circuit breaker '#{circuit_name}' is open. Retry after #{@retry_after_seconds} seconds.")
    end
  end
end