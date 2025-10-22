# frozen_string_literal: true

require 'securerandom'

# Value Object representing a unique blockchain provenance identifier
# Ensures strong typing and validation of provenance IDs
class ProvenanceId
  # Regular expression for validating provenance ID format
  FORMAT_REGEX = /^PROV-[A-F0-9]{32}$/.freeze

  attr_reader :value

  # Create a new ProvenanceId
  # @param value [String] the provenance ID value
  # @raise [ArgumentError] if the ID format is invalid
  def initialize(value)
    @value = value.to_s.upcase

    raise ArgumentError, 'Invalid provenance ID format' unless valid?
  end

  # Generate a new unique provenance ID
  # @return [ProvenanceId] new provenance ID
  def self.generate
    new("PROV-#{SecureRandom.hex(16).upcase}")
  end

  # Create from existing string value
  # @param value [String] existing provenance ID
  # @return [ProvenanceId] provenance ID object
  def self.from_string(value)
    new(value)
  end

  # Check if the ID is valid
  # @return [Boolean] true if valid format
  def valid?
    @value.match?(FORMAT_REGEX)
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

  # Equality comparison
  # @param other [ProvenanceId] other ID to compare
  # @return [Boolean] true if equal
  def ==(other)
    return false unless other.is_a?(ProvenanceId)

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

  private

  # Validate the provenance ID format
  # Uses memoization for performance
  def validate_format
    @validation_result ||= begin
      @value.match?(FORMAT_REGEX)
    end
  end
end