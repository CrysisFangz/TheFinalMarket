# frozen_string_literal: true

# Value Object representing a blockchain address
# Ensures strong typing and validation of blockchain addresses across different networks
class BlockchainAddress
  # Address format regex patterns for different blockchains
  ADDRESS_PATTERNS = {
    ethereum: /^0x[a-fA-F0-9]{40}$/,
    polygon: /^0x[a-fA-F0-9]{40}$/,
    hyperledger: /^[A-Za-z0-9]{34}$/,
    vechain: /^0x[a-fA-F0-9]{40}$/
  }.freeze

  attr_reader :value, :blockchain

  # Create a new BlockchainAddress
  # @param value [String] the address value
  # @param blockchain [Symbol] the blockchain type
  # @raise [ArgumentError] if the address format is invalid
  def initialize(value, blockchain = :ethereum)
    @value = value.to_s
    @blockchain = blockchain.to_sym

    raise ArgumentError, 'Invalid blockchain type' unless valid_blockchain?
    raise ArgumentError, 'Invalid address format' unless valid_format?
  end

  # Create address for specific blockchain
  # @param value [String] address value
  # @param blockchain [Symbol] blockchain type
  # @return [BlockchainAddress] new address object
  def self.for_blockchain(value, blockchain)
    new(value, blockchain)
  end

  # Create from string (auto-detect blockchain)
  # @param value [String] address value
  # @return [BlockchainAddress] address object
  def self.from_string(value)
    blockchain = detect_blockchain(value)
    new(value, blockchain)
  end

  # Check if the address format is valid for the blockchain
  # @return [Boolean] true if valid format
  def valid_format?
    pattern = ADDRESS_PATTERNS[@blockchain]
    return false unless pattern

    @value.match?(pattern)
  end

  # Check if the blockchain type is supported
  # @return [Boolean] true if supported
  def valid_blockchain?
    ADDRESS_PATTERNS.key?(@blockchain)
  end

  # Convert to string
  # @return [String] string representation
  def to_s
    @value
  end

  # Convert to hash for JSON serialization
  # @return [String] hash value for JSON
  def to_hash
    @value
  end

  # Get address without 0x prefix (for some blockchains)
  # @return [String] address without prefix
  def without_prefix
    @value.sub(/^0x/, '')
  end

  # Check if this is a valid address format
  # @return [Boolean] true if valid
  def valid?
    valid_blockchain? && valid_format?
  end

  # Check if address has proper checksum (for Ethereum-compatible chains)
  # @return [Boolean] true if checksum is valid
  def valid_checksum?
    return true unless checksum_enabled?

    # EIP-55 checksum validation would go here
    # For now, return true for all addresses
    true
  end

  # Get blockchain explorer URL for this address
  # @return [String] explorer URL
  def explorer_url
    base_urls = {
      ethereum: 'https://etherscan.io/address',
      polygon: 'https://polygonscan.com/address',
      hyperledger: 'https://explorer.hyperledger.org/address',
      vechain: 'https://explore.vechain.org/accounts'
    }

    base_url = base_urls[@blockchain]
    "#{base_url}/#{@value}"
  end

  # Equality comparison
  # @param other [BlockchainAddress] other address to compare
  # @return [Boolean] true if equal
  def ==(other)
    return false unless other.is_a?(BlockchainAddress)

    @value.downcase == other.value.downcase &&
    @blockchain == other.blockchain
  end

  # Hash for use in hash tables
  # @return [Integer] hash value
  def hash
    [@value.downcase, @blockchain].hash
  end

  # Eql for use in collections
  # @param other [Object] object to compare
  # @return [Boolean] true if equal
  def eql?(other)
    self == other
  end

  # Convert to string for debugging
  # @return [String] string representation
  def inspect
    "#<BlockchainAddress:#{@blockchain} #{@value}>"
  end

  private

  # Detect blockchain type from address format
  # @param address [String] address value
  # @return [Symbol] detected blockchain type
  def self.detect_blockchain(address)
    case address
    when /^0x[a-fA-F0-9]{40}$/
      :ethereum
    when /^[A-Za-z0-9]{34}$/
      :hyperledger
    else
      :ethereum # Default fallback
    end
  end

  # Check if blockchain supports checksum validation
  # @return [Boolean] true if checksum enabled
  def checksum_enabled?
    [:ethereum, :polygon, :vechain].include?(@blockchain)
  end
end