# frozen_string_literal: true

# SmartContractQueryService handles cached queries for smart contract data.
class SmartContractQueryService
  CACHE_EXPIRY = 5.minutes

  def self.balance(smart_contract)
    cache_key = "smart_contract_balance_#{smart_contract.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      BlockchainAdapter.query_contract(smart_contract.contract_address, 'getBalance')
    end
  end

  def self.contract_state(smart_contract)
    cache_key = "smart_contract_state_#{smart_contract.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      {
        address: smart_contract.contract_address,
        status: smart_contract.status,
        balance: balance(smart_contract),
        executions: smart_contract.contract_executions.count,
        deployed_at: smart_contract.deployed_at,
        blockchain_url: smart_contract.blockchain_explorer_url
      }
    end
  end

  def self.clear_cache(smart_contract)
    Rails.cache.delete("smart_contract_balance_#{smart_contract.id}")
    Rails.cache.delete("smart_contract_state_#{smart_contract.id}")
  end
end