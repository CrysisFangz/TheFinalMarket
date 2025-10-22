# frozen_string_literal: true

# Circuit Breaker pattern implementation for resilience
# Prevents cascading failures by failing fast when services are down
# Extracted as a concern for reusability across the application
module CircuitBreaker
  class OpenError < StandardError; end

  # Circuit breaker state machine
  class State
    attr_reader :name, :failure_count, :last_failure_time

    def initialize(name)
      @name = name
      @failure_count = 0
      @last_failure_time = nil
      @state = :closed
    end

    def closed?
      @state == :closed
    end

    def open?
      @state == :open
    end

    def half_open?
      @state == :half_open
    end

    def record_success
      reset
    end

    def record_failure
      @failure_count += 1
      @last_failure_time = Time.current

      if @failure_count >= circuit_breaker_threshold
        @state = :open
      end
    end

    def attempt_reset
      if Time.current - @last_failure_time > circuit_breaker_timeout
        @state = :half_open
        @failure_count = 0
      end
    end

    def reset
      @state = :closed
      @failure_count = 0
      @last_failure_time = nil
    end

    private

    def circuit_breaker_threshold
      AnalyticsMetricConfiguration.circuit_breaker_threshold
    end

    def circuit_breaker_timeout
      AnalyticsMetricConfiguration.circuit_breaker_timeout
    end
  end

  # Main circuit breaker class
  class Breaker
    def initialize(name:)
      @name = name
      @state = State.new(name)
    end

    def call
      if @state.open?
        attempt_reset
        raise OpenError, "Circuit breaker '#{@name}' is open"
      end

      begin
        result = yield
        @state.record_success
        result
      rescue StandardError => e
        @state.record_failure
        raise e
      end
    end

    private

    def attempt_reset
      @state.attempt_reset
    end
  end

  # Class method to create and use a circuit breaker
  def self.with_circuit_breaker(name: 'default')
    breaker = Breaker.new(name: name)
    breaker.call { yield }
  rescue OpenError
    Rails.logger.warn("Circuit breaker '#{name}' is open")
    nil
  end

  # Global circuit breakers registry
  @@breakers = {}

  def self.breaker(name)
    @@breakers[name] ||= Breaker.new(name: name)
  end

  def self.reset(name)
    breaker(name).reset
  end

  def self.status(name)
    breaker = @@breakers[name]
    return :not_found unless breaker

    {
      state: breaker.state.name,
      failure_count: breaker.state.failure_count,
      last_failure_time: breaker.state.last_failure_time
    }
  end

  def self.all_status
    @@breakers.transform_values do |breaker|
      status(breaker.name)
    end
  end
end