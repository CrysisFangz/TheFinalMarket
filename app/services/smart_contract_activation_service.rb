# frozen_string_literal: true

# SmartContractActivationService handles activation of deployed smart contracts.
class SmartContractActivationService
  include ActiveModel::Validations

  attr_reader :smart_contract

  def initialize(smart_contract)
    @smart_contract = smart_contract
  end

  def call
    return Result.failure('Contract must be deployed') unless smart_contract.deployed?

    begin
      smart_contract.update!(status: :active, activated_at: Time.current)

      # Log event
      log_event('activated', { activated_at: smart_contract.activated_at })

      Result.success('Contract activated successfully')
    rescue => e
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