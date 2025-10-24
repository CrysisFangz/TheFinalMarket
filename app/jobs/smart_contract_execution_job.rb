# frozen_string_literal: true

# Background job for executing smart contract functions asynchronously.
class SmartContractExecutionJob < ApplicationJob
  queue_as :default

  def perform(execution_id)
    execution = ContractExecution.find(execution_id)
    smart_contract = execution.smart_contract

    result = BlockchainAdapter.execute_function(smart_contract.contract_address, execution.function_name, execution.parameters)

    execution.update!(
      status: :completed,
      result: result,
      transaction_hash: result[:tx_hash],
      gas_used: result[:gas_used]
    )

    log_event(smart_contract, 'executed', { function: execution.function_name, result: result })
  rescue => e
    execution.update!(status: :failed)
    Rails.logger.error("Execution failed for ContractExecution #{execution_id}: #{e.message}")
  end

  private

  def log_event(smart_contract, event_type, data)
    Rails.logger.info("SmartContract #{smart_contract.id} #{event_type}: #{data}")
    # In full implementation, create an Event record
  end
end