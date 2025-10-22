# frozen_string_literal: true

require 'test_helper'

class ReputationCircuitBreakerTest < ActiveSupport::TestCase
  setup do
    @circuit_breaker = ReputationCircuitBreaker.instance
    @user_id = users(:one).id
  end

  # Test circuit breaker initialization
  test 'initializes with correct configurations' do
    status = @circuit_breaker.circuit_status

    expected_circuits = [
      :reputation_calculation,
      :reputation_storage,
      :reputation_analytics,
      :external_api_calls
    ]

    expected_circuits.each do |circuit_name|
      assert_includes status.keys, circuit_name
      assert_equal :closed, status[circuit_name][:state]
      assert_equal 0, status[circuit_name][:failure_count]
    end
  end

  # Test successful operation execution
  test 'executes successful operations' do
    result = nil

    @circuit_breaker.execute_calculation do
      result = 'success'
    end

    assert_equal 'success', result
  end

  # Test circuit breaker opening after failures
  test 'opens circuit after failure threshold' do
    # Mock failures to reach threshold
    failure_circuit = CircuitBreaker.new(failure_threshold: 2, recovery_timeout: 1.second)

    # First failure
    assert_raises(StandardError) do
      failure_circuit.execute do
        raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
      end
    end

    assert_equal :closed, failure_circuit.state
    assert_equal 1, failure_circuit.failure_count

    # Second failure - should open circuit
    assert_raises(CircuitBreaker::OpenCircuitError) do
      failure_circuit.execute do
        raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
      end
    end

    assert_equal :open, failure_circuit.state
    assert_equal 2, failure_circuit.failure_count
  end

  # Test circuit breaker half-open state
  test 'transitions to half-open after recovery timeout' do
    failure_circuit = CircuitBreaker.new(failure_threshold: 1, recovery_timeout: 1.second)

    # Cause failure to open circuit
    assert_raises(CircuitBreaker::OpenCircuitError) do
      failure_circuit.execute do
        raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
      end
    end

    assert_equal :open, failure_circuit.state

    # Wait for recovery timeout
    sleep(1.1)

    # Next call should be half-open
    assert_raises(CircuitBreaker::HalfOpenCircuitError) do
      failure_circuit.execute do
        # This would be the retry attempt
      end
    end

    assert_equal :half_open, failure_circuit.state
  end

  # Test circuit breaker reset after success
  test 'resets after successful half-open execution' do
    failure_circuit = CircuitBreaker.new(failure_threshold: 1, recovery_timeout: 1.second)

    # Cause failure
    assert_raises(CircuitBreaker::OpenCircuitError) do
      failure_circuit.execute do
        raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
      end
    end

    # Wait for recovery and succeed
    sleep(1.1)

    result = failure_circuit.execute do
      'success'
    end

    assert_equal 'success', result
    assert_equal :closed, failure_circuit.state
    assert_equal 0, failure_circuit.failure_count
  end

  # Test circuit breaker with reputation operations
  test 'handles reputation calculation failures' do
    # Mock a calculation service failure
    ReputationCalculationService.stub :new, ->(*) { raise ActiveRecord::ConnectionTimeoutError.new('DB timeout') } do
      assert_raises(CircuitBreaker::OpenCircuitError) do
        @circuit_breaker.execute_calculation do
          # This would fail and open the circuit
        end
      end
    end
  end

  # Test circuit breaker status monitoring
  test 'provides circuit status information' do
    status = @circuit_breaker.circuit_status

    assert status.is_a?(Hash)
    assert status[:reputation_calculation].present?

    circuit_info = status[:reputation_calculation]
    assert_includes circuit_info.keys, :state
    assert_includes circuit_info.keys, :failure_count
    assert_includes circuit_info.keys, :last_failure_time
    assert_includes circuit_info.keys, :next_retry_time
  end

  # Test circuit breaker reset functionality
  test 'resets all circuits' do
    # Open a circuit first
    assert_raises(CircuitBreaker::OpenCircuitError) do
      @circuit_breaker.execute_calculation do
        raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
      end
    end

    # Reset all circuits
    @circuit_breaker.reset_all_circuits

    # Should be able to execute again
    result = @circuit_breaker.execute_calculation do
      'success after reset'
    end

    assert_equal 'success after reset', result
  end

  # Test circuit breaker health check
  test 'reports circuit health correctly' do
    # All circuits should be healthy initially
    assert @circuit_breaker.healthy?

    # Open one circuit
    assert_raises(CircuitBreaker::OpenCircuitError) do
      @circuit_breaker.execute_calculation do
        raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
      end
    end

    # Should not be healthy now
    assert_not @circuit_breaker.healthy?
  end

  # Test resilience patterns integration
  test 'integrates with retry pattern' do
    retry_count = 0

    # Mock operation that fails twice then succeeds
    mock_operation = -> do
      retry_count += 1
      raise StandardError.new('Temporary failure') if retry_count < 3
      'success'
    end

    # Should succeed after retries
    result = nil
    assert_nothing_raised do
      ReputationOperationWrapper.execute_calculation do
        if retry_count < 3
          raise StandardError.new('Temporary failure')
        else
          result = 'success'
        end
      end
    end

    assert_equal 'success', result
    assert_equal 3, retry_count
  end

  # Test timeout pattern integration
  test 'handles operation timeouts' do
    # Mock slow operation
    slow_operation = -> do
      sleep(2)
      'too slow'
    end

    assert_raises(ReputationResiliencePatterns::ReputationTimeoutError) do
      ReputationOperationWrapper.execute_calculation do
        with_timeout(1.second) do
          sleep(2)
          'too slow'
        end
      end
    end
  end

  # Test bulkhead pattern integration
  test 'limits concurrent operations' do
    semaphore = Concurrent::Semaphore.new(2)

    operations_running = 0
    operations_completed = 0

    # Start operations that acquire semaphore
    3.times do
      Thread.new do
        begin
          semaphore.acquire do
            operations_running += 1
            sleep(0.1) # Simulate work
            operations_running -= 1
            operations_completed += 1
          end
        rescue Concurrent::Semaphore::SemaphoreLockedError
          # Expected for third operation
        end
      end
    end

    sleep(0.2) # Wait for operations to complete

    assert_equal 2, operations_completed # Only 2 should complete due to bulkhead limit
  end

  # Test fallback pattern
  test 'provides fallback on failure' do
    fallback_used = false

    result = with_fallback('fallback_value') do
      raise StandardError.new('Operation failed')
    end

    assert_equal 'fallback_value', result
  end

  # Test circuit breaker error handling
  test 'handles unexpected exceptions' do
    # Mock unexpected exception (not in expected list)
    assert_raises(RuntimeError) do
      @circuit_breaker.execute_calculation do
        raise RuntimeError.new('Unexpected error')
      end
    end

    # Circuit should remain closed for unexpected exceptions
    status = @circuit_breaker.circuit_status
    assert_equal :closed, status[:reputation_calculation][:state]
  end

  # Test circuit breaker monitoring
  test 'records circuit events for monitoring' do
    monitor = ReputationCircuitBreakerMonitor.instance
    initial_metrics = monitor.get_circuit_metrics

    # Trigger a circuit event
    assert_raises(CircuitBreaker::OpenCircuitError) do
      @circuit_breaker.execute_calculation do
        raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
      end
    end

    # Check that metrics were recorded
    final_metrics = monitor.get_circuit_metrics
    assert final_metrics.size > initial_metrics.size
  end

  # Test circuit breaker configuration validation
  test 'validates circuit configurations' do
    # Test with invalid configuration
    assert_raises(ArgumentError) do
      @circuit_breaker.execute_with_custom_config(:invalid_circuit) do
        'test'
      end
    end
  end

  # Test circuit breaker performance
  test 'executes quickly for successful operations' do
    iterations = 100
    start_time = Time.current

    iterations.times do
      @circuit_breaker.execute_calculation do
        'quick operation'
      end
    end

    duration = Time.current - start_time

    # Should complete 100 operations in less than 1 second
    assert duration < 1.second
  end

  # Test circuit breaker memory usage
  test 'maintains reasonable memory footprint' do
    # Execute many operations to test memory usage
    1000.times do |i|
      @circuit_breaker.execute_calculation do
        "operation #{i}"
      end
    end

    # Should not accumulate excessive state
    status = @circuit_breaker.circuit_status
    assert status.values.all? { |circuit| circuit[:failure_count] <= 10 }
  end

  # Test circuit breaker thread safety
  test 'handles concurrent operations safely' do
    results = []
    errors = []

    # Run concurrent operations
    10.times.map do |i|
      Thread.new do
        begin
          result = @circuit_breaker.execute_calculation do
            "thread #{i}"
          end
          results << result
        rescue StandardError => e
          errors << e
        end
      end
    end.each(&:join)

    # All operations should succeed
    assert_equal 10, results.size
    assert_equal 0, errors.size
  end

  # Test circuit breaker recovery
  test 'recovers from failures correctly' do
    # Cause multiple failures to open circuit
    3.times do
      assert_raises(CircuitBreaker::OpenCircuitError) do
        @circuit_breaker.execute_calculation do
          raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
        end
      end
    end

    # Wait for recovery timeout
    sleep(1.1)

    # Should allow retry attempt
    assert_raises(CircuitBreaker::HalfOpenCircuitError) do
      @circuit_breaker.execute_calculation do
        # This would be the retry attempt
      end
    end
  end

  # Test circuit breaker metrics
  test 'provides detailed failure information' do
    # Cause a failure
    begin
      @circuit_breaker.execute_calculation do
        raise ActiveRecord::ConnectionTimeoutError.new('Connection failed')
      end
    rescue CircuitBreaker::OpenCircuitError
      # Expected
    end

    status = @circuit_breaker.circuit_status
    circuit_info = status[:reputation_calculation]

    assert_equal :open, circuit_info[:state]
    assert_equal 1, circuit_info[:failure_count]
    assert circuit_info[:last_failure_time].present?
    assert circuit_info[:next_retry_time].present?
  end
end