# Payment Circuit Breaker
# Implements circuit breaker pattern for fault tolerance
# with adaptive recovery and failure tracking.

class PaymentCircuitBreaker
  CircuitOpenError = Class.new(StandardError)

  def initialize(failure_threshold: 5, recovery_timeout: 60)
    @failure_threshold = failure_threshold
    @recovery_timeout = recovery_timeout
    @state = :closed
    @failure_count = 0
    @last_failure_time = nil
  end

  def execute
    case @state
    when :closed
      execute_closed_state { yield }
    when :open
      handle_open_state
    when :half_open
      execute_half_open_state { yield }
    end
  end

  private

  def execute_closed_state
    yield
  rescue StandardError => e
    record_failure
    raise e
  end

  def handle_open_state
    if circuit_should_attempt_reset?
      transition_to_half_open
    else
      raise CircuitOpenError.new("Circuit breaker is OPEN")
    end
  end

  def execute_half_open_state
    yield
    transition_to_closed
  rescue StandardError => e
    transition_to_open
    raise e
  end

  def record_failure
    @failure_count += 1
    @last_failure_time = Time.current

    if @failure_count >= @failure_threshold
      transition_to_open
    end
  end

  def circuit_should_attempt_reset?
    @last_failure_time && (Time.current - @last_failure_time) > @recovery_timeout
  end

  def transition_to_open
    @state = :open
    @failure_count = 0
  end

  def transition_to_half_open
    @state = :half_open
  end

  def transition_to_closed
    @state = :closed
    @failure_count = 0
  end
end