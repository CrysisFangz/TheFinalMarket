# frozen_string_literal: true

require_relative '../domain/value_objects/event_hash'
require_relative '../infrastructure/circuit_breaker'

# Service for blockchain operations with circuit breaker pattern
# Provides resilient blockchain interaction with fallback mechanisms
class BlockchainService
  # Error classes for different blockchain failures
  class BlockchainError < StandardError; end
  class NetworkError < BlockchainError; end
  class TimeoutError < BlockchainError; end
  class ValidationError < BlockchainError; end

  # Circuit breaker configuration
  CIRCUIT_BREAKER_CONFIG = {
    failure_threshold: 5,
    recovery_timeout: 60,
    success_threshold: 2
  }.freeze

  # Initialize blockchain service
  def initialize
    @circuit_breakers = {}
    @cache = Rails.cache
  end

  # Write provenance record to blockchain
  # @param provenance [BlockchainProvenance] provenance to write
  # @return [Hash] write result with transaction hash
  # @raise [BlockchainError] if write fails
  def self.write_provenance(provenance)
    new.write_provenance(provenance)
  end

  # Write event to blockchain
  # @param event [ProvenanceEvent] event to write
  # @return [Hash] write result with transaction hash
  # @raise [BlockchainError] if write fails
  def self.write_event(event)
    new.write_event(event)
  end

  # Fetch provenance data from blockchain
  # @param provenance [BlockchainProvenance] provenance to fetch
  # @return [Hash] blockchain data
  # @raise [BlockchainError] if fetch fails
  def self.fetch_provenance_data(provenance)
    new.fetch_provenance_data(provenance)
  end

  # Verify provenance on blockchain
  # @param provenance [BlockchainProvenance] provenance to verify
  # @return [Hash] verification result
  # @raise [BlockchainError] if verification fails
  def self.verify_provenance(provenance)
    new.verify_provenance(provenance)
  end

  # Write provenance record to blockchain with circuit breaker
  # @param provenance [BlockchainProvenance] provenance to write
  # @return [Hash] write result
  def write_provenance(provenance)
    with_circuit_breaker(:write_provenance) do
      perform_write_provenance(provenance)
    end
  end

  # Write event to blockchain with circuit breaker
  # @param event [ProvenanceEvent] event to write
  # @return [Hash] write result
  def write_event(event)
    with_circuit_breaker(:write_event) do
      perform_write_event(event)
    end
  end

  # Fetch provenance data from blockchain with circuit breaker
  # @param provenance [BlockchainProvenance] provenance to fetch
  # @return [Hash] blockchain data
  def fetch_provenance_data(provenance)
    cache_key = "blockchain_data_#{provenance.blockchain_id}"

    # Try cache first
    cached_data = @cache.read(cache_key)
    return cached_data if cached_data.present?

    result = with_circuit_breaker(:fetch_provenance) do
      perform_fetch_provenance(provenance)
    end

    # Cache successful results for 5 minutes
    @cache.write(cache_key, result, expires_in: 5.minutes) if result[:verified]
    result
  end

  # Verify provenance on blockchain with circuit breaker
  # @param provenance [BlockchainProvenance] provenance to verify
  # @return [Hash] verification result
  def verify_provenance(provenance)
    with_circuit_breaker(:verify_provenance) do
      perform_verify_provenance(provenance)
    end
  end

  private

  # Perform actual provenance write to blockchain
  # @param provenance [BlockchainProvenance] provenance to write
  # @return [Hash] write result
  def perform_write_provenance(provenance)
    case provenance.blockchain.to_sym
    when :ethereum, :polygon
      write_to_evm_blockchain(provenance, 'provenance')
    when :hyperledger
      write_to_hyperledger(provenance, 'provenance')
    when :vechain
      write_to_vechain(provenance, 'provenance')
    else
      raise ValidationError, "Unsupported blockchain: #{provenance.blockchain}"
    end
  rescue Timeout::Error
    raise TimeoutError, 'Blockchain write timeout'
  rescue StandardError => e
    raise NetworkError, "Blockchain write failed: #{e.message}"
  end

  # Perform actual event write to blockchain
  # @param event [ProvenanceEvent] event to write
  # @return [Hash] write result
  def perform_write_event(event)
    provenance = event.blockchain_provenance

    case provenance.blockchain.to_sym
    when :ethereum, :polygon
      write_to_evm_blockchain(provenance, 'event', event)
    when :hyperledger
      write_to_hyperledger(provenance, 'event', event)
    when :vechain
      write_to_vechain(provenance, 'event', event)
    else
      raise ValidationError, "Unsupported blockchain: #{provenance.blockchain}"
    end
  rescue Timeout::Error
    raise TimeoutError, 'Blockchain write timeout'
  rescue StandardError => e
    raise NetworkError, "Blockchain write failed: #{e.message}"
  end

  # Perform actual provenance fetch from blockchain
  # @param provenance [BlockchainProvenance] provenance to fetch
  # @return [Hash] blockchain data
  def perform_fetch_provenance(provenance)
    case provenance.blockchain.to_sym
    when :ethereum, :polygon
      fetch_from_evm_blockchain(provenance)
    when :hyperledger
      fetch_from_hyperledger(provenance)
    when :vechain
      fetch_from_vechain(provenance)
    else
      raise ValidationError, "Unsupported blockchain: #{provenance.blockchain}"
    end
  rescue Timeout::Error
    raise TimeoutError, 'Blockchain fetch timeout'
  rescue StandardError => e
    raise NetworkError, "Blockchain fetch failed: #{e.message}"
  end

  # Perform actual provenance verification on blockchain
  # @param provenance [BlockchainProvenance] provenance to verify
  # @return [Hash] verification result
  def perform_verify_provenance(provenance)
    blockchain_data = perform_fetch_provenance(provenance)

    # Verify data integrity
    local_hash = calculate_local_hash(provenance)
    blockchain_hash = blockchain_data[:hash]

    verified = local_hash == blockchain_hash

    {
      verified: verified,
      hash: blockchain_hash,
      timestamp: blockchain_data[:timestamp],
      block_number: blockchain_data[:block_number],
      gas_used: blockchain_data[:gas_used]
    }
  rescue StandardError => e
    raise ValidationError, "Verification failed: #{e.message}"
  end

  # Write to EVM-compatible blockchain (Ethereum, Polygon)
  # @param provenance [BlockchainProvenance] provenance record
  # @param type [String] type of write ('provenance' or 'event')
  # @param event [ProvenanceEvent, nil] event if type is 'event'
  # @return [Hash] write result
  def write_to_evm_blockchain(provenance, type, event = nil)
    # Simulate blockchain interaction
    sleep(0.1) # Simulate network latency

    if rand(100) < 95 # 95% success rate
      {
        success: true,
        transaction_hash: generate_transaction_hash,
        block_number: rand(1000000..9999999),
        gas_used: rand(50000..200000),
        timestamp: Time.current
      }
    else
      raise NetworkError, 'Simulated blockchain network error'
    end
  end

  # Write to Hyperledger blockchain
  # @param provenance [BlockchainProvenance] provenance record
  # @param type [String] type of write ('provenance' or 'event')
  # @param event [ProvenanceEvent, nil] event if type is 'event'
  # @return [Hash] write result
  def write_to_hyperledger(provenance, type, event = nil)
    # Simulate blockchain interaction
    sleep(0.15) # Hyperledger typically has higher latency

    {
      success: true,
      transaction_id: "hl-#{SecureRandom.hex(32)}",
      block_number: rand(100000..999999),
      timestamp: Time.current
    }
  end

  # Write to VeChain blockchain
  # @param provenance [BlockchainProvenance] provenance record
  # @param type [String] type of write ('provenance' or 'event')
  # @param event [ProvenanceEvent, nil] event if type is 'event'
  # @return [Hash] write result
  def write_to_vechain(provenance, type, event = nil)
    # Simulate blockchain interaction
    sleep(0.12)

    {
      success: true,
      transaction_hash: "0x#{SecureRandom.hex(32)}",
      block_number: rand(10000000..99999999),
      gas_used: rand(20000..80000),
      timestamp: Time.current
    }
  end

  # Fetch data from EVM-compatible blockchain
  # @param provenance [BlockchainProvenance] provenance to fetch
  # @return [Hash] blockchain data
  def fetch_from_evm_blockchain(provenance)
    sleep(0.08) # Simulate fetch latency

    {
      verified: true,
      hash: provenance.verification_hash || generate_transaction_hash,
      timestamp: provenance.created_at,
      block_number: rand(1000000..9999999),
      gas_used: rand(50000..200000)
    }
  end

  # Fetch data from Hyperledger blockchain
  # @param provenance [BlockchainProvenance] provenance to fetch
  # @return [Hash] blockchain data
  def fetch_from_hyperledger(provenance)
    sleep(0.1)

    {
      verified: true,
      transaction_id: "hl-#{SecureRandom.hex(32)}",
      timestamp: provenance.created_at,
      block_number: rand(100000..999999)
    }
  end

  # Fetch data from VeChain blockchain
  # @param provenance [BlockchainProvenance] provenance to fetch
  # @return [Hash] blockchain data
  def fetch_from_vechain(provenance)
    sleep(0.09)

    {
      verified: true,
      hash: provenance.verification_hash || "0x#{SecureRandom.hex(32)}",
      timestamp: provenance.created_at,
      block_number: rand(10000000..99999999),
      gas_used: rand(20000..80000)
    }
  end

  # Calculate local hash for verification
  # @param provenance [BlockchainProvenance] provenance record
  # @return [String] calculated hash
  def calculate_local_hash(provenance)
    data = {
      blockchain_id: provenance.blockchain_id,
      product_id: provenance.product_id,
      created_at: provenance.created_at,
      origin_data: provenance.origin_data
    }

    EventHash.from_data(data).to_s
  end

  # Execute operation with circuit breaker
  # @param operation [Symbol] operation name for circuit breaker
  # @yield block to execute
  # @return [Object] block result
  def with_circuit_breaker(operation, &block)
    circuit_breaker = get_circuit_breaker(operation)
    circuit_breaker.execute(&block)
  end

  # Get or create circuit breaker for operation
  # @param operation [Symbol] operation name
  # @return [CircuitBreaker] circuit breaker instance
  def get_circuit_breaker(operation)
    @circuit_breakers[operation] ||= CircuitBreaker.new(
      operation,
      **CIRCUIT_BREAKER_CONFIG
    )
  end

  # Generate a mock transaction hash
  # @return [String] transaction hash
  def generate_transaction_hash
    "0x#{SecureRandom.hex(32)}"
  end
end