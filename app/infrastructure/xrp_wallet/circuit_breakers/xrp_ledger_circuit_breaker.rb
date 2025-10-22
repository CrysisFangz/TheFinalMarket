# frozen_string_literal: true

require 'monitor'

module XrpWallet
  module Infrastructure
    module CircuitBreakers
      # Circuit breaker implementation for XRP Ledger operations
      class XrpLedgerCircuitBreaker
        # Circuit breaker states
        STATES = {
          closed: :closed,     # Normal operation
          open: :open,         # Failing, requests rejected
          half_open: :half_open # Testing if service recovered
        }.freeze

        # Configuration defaults
        DEFAULT_CONFIG = {
          failure_threshold: 5,           # Open circuit after N failures
          recovery_timeout: 60,           # Wait N seconds before half-open
          success_threshold: 3,           # Close circuit after N successes
          timeout: 10                     # Request timeout in seconds
        }.freeze

        include MonitorMixin

        # @param config [Hash] Circuit breaker configuration
        def initialize(config = {})
          super() # Initialize MonitorMixin

          @config = DEFAULT_CONFIG.merge(config)
          @state = STATES[:closed]
          @failure_count = 0
          @success_count = 0
          @last_failure_time = nil
          @next_attempt_at = Time.now
        end

        # Execute block with circuit breaker protection
        # @param block [Proc] Block to execute
        # @return [Object] Block result
        # @raise [CircuitBreakerOpenError] if circuit is open
        def call
          synchronize do
            case state
            when STATES[:closed]
              execute_closed
            when STATES[:open]
              handle_open_circuit
            when STATES[:half_open]
              execute_half_open
            end
          end
        end

        # @return [Symbol] Current circuit breaker state
        def state
          synchronize do
            # Check if we should transition from open to half-open
            if @state == STATES[:open] && Time.now >= @next_attempt_at
              @state = STATES[:half_open]
              @success_count = 0
            end

            @state
          end
        end

        # @return [Hash] Circuit breaker statistics
        def stats
          synchronize do
            {
              state: state,
              failure_count: @failure_count,
              success_count: @success_count,
              last_failure_time: @last_failure_time,
              next_attempt_at: @next_attempt_at
            }
          end
        end

        private

        def execute_closed
          begin
            result = yield
            record_success
            result
          rescue => e
            record_failure
            raise e
          end
        end

        def handle_open_circuit
          raise CircuitBreakerOpenError,
                "Circuit breaker is OPEN. Next attempt at: #{@next_attempt_at}"
        end

        def execute_half_open
          begin
            result = yield
            record_success
            result
          rescue => e
            record_failure
            raise e
          end
        end

        def record_success
          @success_count += 1

          if @success_count >= @config[:success_threshold]
            @state = STATES[:closed]
            @failure_count = 0
            @success_count = 0
          end
        end

        def record_failure
          @failure_count += 1
          @last_failure_time = Time.now

          if @failure_count >= @config[:failure_threshold]
            @state = STATES[:open]
            @next_attempt_at = Time.now + @config[:recovery_timeout]
          end
        end

        # Custom error for open circuit breaker
        class CircuitBreakerOpenError < StandardError
          def initialize(message)
            super(message)
          end
        end
      end
    end
  end
end