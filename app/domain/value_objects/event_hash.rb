# frozen_string_literal: true

require 'securerandom'
require 'digest'

# Value Object representing a cryptographic hash for provenance events
# Ensures strong typing and validation of blockchain event hashes
class EventHash
  # Regular expression for validating hash format (64 character hex)
  HASH_REGEX = /^0x[A-F0-9]{64}$/.freeze

  attr_reader :value

  # Create a new EventHash
  # @param value [String] the hash value
  # @raise [ArgumentError] if the hash format is invalid
  def initialize(value)
    @value = value.to_s.downcase

    raise ArgumentError, 'Invalid event hash format' unless valid?
  end

  # Generate a new random hash for events
  # @return [EventHash] new event hash
  def self.generate
    new("0x#{SecureRandom.hex(32)}")
  end

  # Generate a deterministic hash from data
  # @param data [String, Hash] data to hash
  # @return [EventHash] deterministic hash
  def self.from_data(data)
    data_string = data.is_a?(Hash) ? data.to_json : data.to_s
    hash_value = Digest::SHA256.hexdigest(data_string)
    new("0x#{hash_value}")
  end

  # Create from existing string value
  # @param value [String] existing hash value
  # @return [EventHash] event hash object
  def self.from_string(value)
    new(value)
  end

  # Check if the hash is valid
  # @return [Boolean] true if valid format
  def valid?
    @value.match?(HASH_REGEX)
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

  # Get the raw hash without 0x prefix
  # @return [String] raw hash
  def without_prefix
    @value.sub(/^0x/, '')
  end

  # Check if this is a valid blockchain hash format
  # @return [Boolean] true if valid blockchain format
  def blockchain_format?
    valid? && @value.start_with?('0x')
  end

  # Equality comparison
  # @param other [EventHash] other hash to compare
  # @return [Boolean] true if equal
  def ==(other)
    return false unless other.is_a?(EventHash)

    @value == other.value
  end

  # Hash for use in hash tables
  # @return [Integer] hash value
  def hash
    @value.hash
  end

  # Eql for use in collections
  # @param other [Object] object to compare
  # @return [Boolean] true if equal
  def eql?(other)
    self == other
  end

  # Validate the hash format
  # Uses memoization for performance
  def validate_format
    @validation_result ||= begin
      @value.match?(HASH_REGEX)
    end
  end

  private

  # Validate the hash format with additional security checks
  # @return [Boolean] true if valid
  def secure_validation
    return false unless valid?

    # Additional validation: check for all zeros (invalid)
    @value !~ /^0x0{64}$/
  end
end