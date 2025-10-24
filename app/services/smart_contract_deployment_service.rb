# frozen_string_literal: true

# SmartContractDeploymentService handles the deployment of smart contracts.
# Encapsulates business logic for deployment, including validation and state updates.
class SmartContractDeploymentService
  include ActiveModel::Validations

  attr_reader :smart_contract

  def initialize(smart_contract)
    @smart_contract = smart_contract
  end

  def call
    return Result.failure('Contract must be in draft status') unless smart_contract.draft?

    # Validate before deployment
    return Result.failure('Contract is invalid') unless smart_contract.valid?

    # Perform deployment in background for async processing
    SmartContractDeploymentJob.perform_later(smart_contract.id)

    Result.success('Deployment initiated')
  end

  # Synchronous deployment for testing or immediate needs
  def call_sync
    return Result.failure('Contract must be in draft status') unless smart_contract.draft?

    return Result.failure('Contract is invalid') unless smart_contract.valid?

    begin
      deployment_result = BlockchainAdapter.deploy_contract(smart_contract.contract_code, smart_contract.attributes)

      smart_contract.update!(
        status: :deployed,
        contract_address: deployment_result[:address],
        deployment_hash: deployment_result[:tx_hash],
        deployed_at: Time.current
      )

      # Log event
      log_event('deployed', deployment_result)

      Result.success(deployment_result)
    rescue => e
      Result.failure(e.message)
    end
  end

  private

  def log_event(event_type, data)
    # Basic event logging - can be enhanced with Event Sourcing
    Rails.logger.info("SmartContract #{smart_contract.id} #{event_type}: #{data}")
    # In full implementation, create an Event record
  end

  # Simple Result class for handling success/failure
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