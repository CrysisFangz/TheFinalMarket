# frozen_string_literal: true

module Infrastructure
  module Gamification
    # Circuit Breaker for Spin-to-Win operations
    class SpinCircuitBreaker
      include CircuitBreaker

      def initialize
        super(
          name: 'spin_to_win',
          failure_threshold: 5,
          recovery_timeout: 30.seconds,
          monitoring_period: 60.seconds
        )
      end

      def execute(&block)
        super do
          yield
        end
      end
    end
  end
end