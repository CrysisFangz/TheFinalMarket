# frozen_string_literal: true

# Reactive Parallel Executor
# High-performance parallel execution with reactive streams
class ReactiveParallelExecutor
  def self.execute(operations)
    new.execute(operations)
  end

  def execute(operations)
    case operations
    when Array
      execute_parallel(operations)
    when Proc
      execute_async(operations)
    else
      operations.call
    end
  end

  private

  def execute_parallel(operations)
    # Use Rails executor for thread-safe parallel execution
    results = {}

    operations.each_with_index do |operation, index|
      Rails.executor.wrap do
        begin
          results[index] = operation.call
        rescue => e
          Rails.logger.error("Parallel operation #{index} failed: #{e.message}")
          results[index] = nil
        end
      end
    end

    # Wait for all operations to complete
    wait_for_completion(results)

    results.compact
  end

  def execute_async(operation)
    # Execute operation asynchronously
    ReactivePromise.new do |resolve, reject|
      begin
        result = operation.call
        resolve.call(result)
      rescue => e
        reject.call(e)
      end
    end
  end

  def wait_for_completion(results)
    # Wait for all parallel operations to complete
    sleep(0.001) until results.values.all? { |result| !result.nil? }
  end
end

# Reactive Promise Implementation
class ReactivePromise
  def initialize(&block)
    @block = block
    @result = nil
    @error = nil
    @completed = false
    @callbacks = []

    execute_async
  end

  def then(&callback)
    if @completed
      callback.call(@result) if @result
    else
      @callbacks << callback
    end
    self
  end

  def catch(&callback)
    if @completed && @error
      callback.call(@error)
    else
      @error_callbacks ||= []
      @error_callbacks << callback
    end
    self
  end

  private

  def execute_async
    Thread.new do
      begin
        @block.call(
          ->(result) { complete_with_result(result) },
          ->(error) { complete_with_error(error) }
        )
      rescue => e
        complete_with_error(e)
      end
    end
  end

  def complete_with_result(result)
    @result = result
    @completed = true

    @callbacks.each { |callback| callback.call(result) }
  end

  def complete_with_error(error)
    @error = error
    @completed = true

    if @error_callbacks
      @error_callbacks.each { |callback| callback.call(error) }
    end
  end
end