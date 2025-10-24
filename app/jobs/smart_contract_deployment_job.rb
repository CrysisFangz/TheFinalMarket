# frozen_string_literal: true

# Background job for deploying smart contracts asynchronously.
class SmartContractDeploymentJob < ApplicationJob
  queue_as :default

  def perform(smart_contract_id)
    smart_contract = SmartContract.find(smart_contract_id)

    deployment_result = BlockchainAdapter.deploy_contract(smart_contract.contract_code, smart_contract.attributes)

    smart_contract.update!(
      status: :deployed,
      contract_address: deployment_result[:address],
      deployment_hash: deployment_result[:tx_hash],
      deployed_at: Time.current
    )

    # Log event
    log_event(smart_contract, 'deployed', deployment_result)
  rescue => e
    # Handle failure, e.g., retry or mark as failed
    smart_contract.update!(status: :cancelled) if smart_contract.draft?
    Rails.logger.error("Deployment failed for SmartContract #{smart_contract_id}: #{e.message}")
    # Optionally, notify or create failure record
  end

  private

  def log_event(smart_contract, event_type, data)
    Rails.logger.info("SmartContract #{smart_contract.id} #{event_type}: #{data}")
    # In full implementation, create an Event record for event sourcing
  end
end