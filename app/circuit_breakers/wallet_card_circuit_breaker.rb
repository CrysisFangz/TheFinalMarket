# frozen_string_literal: true

# CircuitBreaker for WalletCard operations to enhance resilience.
# Prevents cascading failures by failing fast when services are down.
class WalletCardCircuitBreaker
  include CircuitBreaker

  # Configure the circuit breaker for wallet operations
  def initialize
    @failure_threshold = 5
    @recovery_timeout = 30.seconds
    @expected_exception = [ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid]
  end

  # Wraps a block in the circuit breaker logic
  def call(&block)
    super
  end
end