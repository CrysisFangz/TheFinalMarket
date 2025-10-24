# frozen_string_literal: true

module CircuitBreakers
  class BaseCircuitBreaker
    attr_reader :name, :failure_count, :last_failure_at, :state

    def initialize(name, failure_threshold: 5, recovery_timeout: 60)
      @name = name
      @failure_threshold = failure_threshold
      @recovery_timeout = recovery_timeout
      @failure_count = 0
      @last_failure_at = nil
      @state = :closed
    end

    def execute
      case state
      when :closed
        begin
          yield
        rescue => e
          record_failure
          raise e
        end
      when :open
        if can_attempt_recovery?
          @state = :half_open
          begin
            yield
            reset
          rescue => e
            record_failure
            raise e
          end
        else
          raise OpenError.new("Circuit breaker #{name} is open")
        end
      when :half_open
        begin
          yield
          reset
        rescue => e
          record_failure
          raise e
        end
      end
    end

    private

    def record_failure
      @failure_count += 1
      @last_failure_at = Time.current
      @state = :open if failure_count >= failure_threshold
    end

    def reset
      @failure_count = 0
      @last_failure_at = nil
      @state = :closed
    end

    def can_attempt_recovery?
      last_failure_at && (Time.current - last_failure_at) > recovery_timeout
    end
  end

  class OpenError < StandardError; end
end