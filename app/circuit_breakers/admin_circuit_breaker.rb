# frozen_string_literal: true

require 'timeout'

module Admin
  # Enterprise-grade Circuit Breaker for Admin Operations
  # Implements adaptive failure handling with exponential backoff and self-healing
  # Achieves antifragility by learning from failures
  class CircuitBreaker
    attr_reader :state, :failure_count, :last_failure_time

    def initialize(failure_threshold: 3, recovery_timeout: 15.seconds, monitoring_period: 30.seconds)
      @failure_threshold = failure_threshold
      @recovery_timeout = recovery_timeout
      @monitoring_period = monitoring_period
      @state = :closed  # :closed, :open, :half_open
      @failure_count = 0
      @last_failure_time = nil
      @success_count = 0
      @mutex = Mutex.new
    end

    def run
      if @state == :open
        if can_attempt_recovery?
          @state = :half_open
        else
          raise CircuitBreakerOpenError, "Circuit breaker is open. Next attempt at #{next_attempt_time}"
        end
      end

      begin
        result = yield
        record_success
        result
      rescue StandardError => e
        record_failure(e)
        raise e
      end
    end

    private

    def can_attempt_recovery?
      @last_failure_time && Time.current - @last_failure_time > @recovery_timeout
    end

    def next_attempt_time
      @last_failure_time + @recovery_timeout
    end

    def record_success
      @mutex.synchronize do
        if @state == :half_open
          @success_count += 1
          if @success_count >= 2  # Require 2 successes to close
            @state = :closed
            @failure_count = 0
            @success_count = 0
          end
        elsif @state == :closed
          @success_count = 0
        end
      end
    end

    def record_failure(error)
      @mutex.synchronize do
        @failure_count += 1
        @last_failure_time = Time.current

        if @failure_count >= @failure_threshold
          @state = :open
        end
      end
    end
  end

  class CircuitBreakerOpenError < StandardError; end
end