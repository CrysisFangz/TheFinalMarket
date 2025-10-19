# frozen_string_literal: true

# CircuitBreaker implements the circuit breaker pattern for resilience
# Protects against cascade failures and provides graceful degradation
#
# States:
# - Closed: Normal operation, requests pass through
# - Open: Failure threshold reached, requests fail fast
# - Half-Open: Testing recovery, limited requests allowed
#
# @example
#   circuit_breaker = CircuitBreaker.new(failure_threshold: 5, recovery_timeout: 30.seconds)
#   result = circuit_breaker.execute do
#     risky_operation
#   end
#
class CircuitBreaker
  # Custom exception for open circuit breaker
  class Open < StandardError
    def initialize(msg = "Circuit breaker is open")
      super
    end
  end

  # Initialize circuit breaker with configuration
  # @param failure_threshold [Integer] Number of failures before opening
  # @param recovery_timeout [ActiveSupport::Duration] Time before attempting recovery
  # @param expected_exception [Class] Exception class that counts as failure
  def initialize(failure_threshold: 5, recovery_timeout: 30.seconds, expected_exception: StandardError)
    @failure_threshold = failure_threshold
    @recovery_timeout = recovery_timeout
    @expected_exception = expected_exception
    @state = :closed
    @failure_count = 0
    @last_failure_time = nil
    @monitor = Monitor.new
  end

  # Execute block with circuit breaker protection
  # @yield Block to execute
  # @return Result of block execution
  # @raise [CircuitBreaker::Open] When circuit breaker is open
  def execute
    @monitor.synchronize do
      case @state
      when :closed
        execute_closed { yield }
      when :open
        handle_open_state
      when :half_open
        execute_half_open { yield }
      end
    end
  end

  # Check if circuit breaker is closed
  # @return [Boolean] True if closed
  def closed?
    @monitor.synchronize { @state == :closed }
  end

  # Check if circuit breaker is open
  # @return [Boolean] True if open
  def open?
    @monitor.synchronize { @state == :open }
  end

  # Get current state
  # @return [Symbol] Current state
  def state
    @monitor.synchronize { @state }
  end

  # Manually reset circuit breaker
  def reset
    @monitor.synchronize do
      @state = :closed
      @failure_count = 0
      @last_failure_time = nil
    end
  end

  private

  # Execute when in closed state
  def execute_closed
    begin
      result = yield
      reset_failure_count
      result
    rescue @expected_exception => e
      record_failure
      raise e
    end
  end

  # Execute when in half-open state
  def execute_half_open
    begin
      result = yield
      transition_to_closed
      result
    rescue @expected_exception => e
      transition_to_open
      raise e
    end
  end

  # Handle open state - fail fast
  def handle_open_state
    if should_attempt_recovery?
      transition_to_half_open
      raise Open.new("Circuit breaker transitioning to half-open for recovery attempt")
    else
      raise Open.new("Circuit breaker is open. Next retry at #{@next_retry_time}")
    end
  end

  # Record a failure and potentially transition states
  def record_failure
    @failure_count += 1
    @last_failure_time = Time.current

    if @failure_count >= @failure_threshold
      transition_to_open
    end
  end

  # Reset failure count on success
  def reset_failure_count
    @failure_count = 0
    @last_failure_time = nil
  end

  # Transition to open state
  def transition_to_open
    @state = :open
    @next_retry_time = Time.current + @recovery_timeout
    Rails.logger.warn(
      "CircuitBreaker transitioned to OPEN state",
      failure_count: @failure_count,
      next_retry_time: @next_retry_time
    )
  end

  # Transition to closed state
  def transition_to_closed
    @state = :closed
    reset_failure_count
    Rails.logger.info("CircuitBreaker transitioned to CLOSED state")
  end

  # Transition to half-open state
  def transition_to_half_open
    @state = :half_open
    Rails.logger.info("CircuitBreaker transitioned to HALF_OPEN state")
  end

  # Check if we should attempt recovery
  def should_attempt_recovery?
    return false unless @last_failure_time.present?

    Time.current >= (@last_failure_time + @recovery_timeout)
  end
end