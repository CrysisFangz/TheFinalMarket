# frozen_string_literal: true

# SmartContractExecutionService handles execution of smart contract functions.
class SmartContractExecutionService
  include ActiveModel::Validations

  attr_reader :smart_contract

  def initialize(smart_contract)
    @smart_contract = smart_contract
  end

  def call(function_name, params = {})
    return Result.failure('Contract must be active') unless smart_contract.active?

    begin
      # Create execution record
      execution = smart_contract.contract_executions.create!(
        function_name: function_name,
        parameters: params,
        status: :pending,
        executed_at: Time.current
      )

      # Execute in background for async
      SmartContractExecutionJob.perform_later(execution.id)

      Result.success('Execution initiated')
    rescue => e
      Result.failure(e.message)
    end
  end

  def call_sync(function_name, params = {})
    return Result.failure('Contract must be active') unless smart_contract.active?

    begin
      execution = smart_contract.contract_executions.create!(
        function_name: function_name,
        parameters: params,
        status: :pending,
        executed_at: Time.current
      )

      result = BlockchainAdapter.execute_function(smart_contract.contract_address, function_name, params)

      execution.update!(
        status: :completed,
        result: result,
        transaction_hash: result[:tx_hash],
        gas_used: result[:gas_used]
      )

      log_event('executed', { function: function_name, result: result })

      Result.success(result)
    rescue => e
      execution.update!(status: :failed) if execution
      Result.failure(e.message)
    end
  end

  private

  def log_event(event_type, data)
    Rails.logger.info("SmartContract #{smart_contract.id} #{event_type}: #{data}")
    # In full implementation, create an Event record
  end

  class Result
    attr_reader :value, :error

    def self.success(value)
      new(value, nil)
    end

    def self.failure(error)
      new(nil, error)
    end

    def initialize(value, error)
      @value = value
      @error = error
    end

    def success?
      @error.nil?
    end

    def failure?
      !success?
    end
  end
end