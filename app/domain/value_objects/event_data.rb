# frozen_string_literal: true

# Value Object representing structured event data for provenance events
# Ensures data integrity and provides type-safe access to event information
class EventData
  attr_reader :data, :timestamp, :metadata

  # Initialize with event data
  # @param data [Hash] the event data
  # @param timestamp [Time] when the event occurred
  # @param metadata [Hash] additional metadata
  def initialize(data = {}, timestamp = nil, metadata = {})
    @data = deep_freeze(data || {})
    @timestamp = timestamp || Time.current
    @metadata = deep_freeze(metadata || {})

    validate_data_integrity
  end

  # Create EventData from hash
  # @param hash [Hash] hash containing event data
  # @return [EventData] new event data object
  def self.from_hash(hash)
    data = hash['data'] || {}
    timestamp = parse_timestamp(hash['timestamp'])
    metadata = hash['metadata'] || {}

    new(data, timestamp, metadata)
  end

  # Convert to hash for serialization
  # @return [Hash] hash representation
  def to_hash
    {
      'data' => @data,
      'timestamp' => @timestamp.iso8601,
      'metadata' => @metadata
    }
  end

  # Convert to JSON
  # @return [String] JSON representation
  def to_json
    JSON.generate(to_hash)
  end

  # Access data with type safety
  # @param key [String, Symbol] data key
  # @param default [Object] default value if key not found
  # @return [Object] data value
  def get(key, default = nil)
    @data[key.to_s] || @data[key.to_sym] || default
  end

  # Set data value (returns new instance)
  # @param key [String, Symbol] data key
  # @param value [Object] data value
  # @return [EventData] new event data with updated value
  def set(key, value)
    new_data = @data.merge(key.to_s => value)
    EventData.new(new_data, @timestamp, @metadata)
  end

  # Check if data contains key
  # @param key [String, Symbol] data key
  # @return [Boolean] true if key exists
  def has_key?(key)
    @data.key?(key.to_s) || @data.key?(key.to_sym)
  end

  # Get all data keys
  # @return [Array] array of keys
  def keys
    @data.keys
  end

  # Get all data values
  # @return [Array] array of values
  def values
    @data.values
  end

  # Merge with other event data
  # @param other [EventData, Hash] data to merge
  # @return [EventData] new merged event data
  def merge(other)
    other_data = other.is_a?(EventData) ? other.data : other
    new_data = @data.merge(other_data)

    EventData.new(new_data, @timestamp, @metadata)
  end

  # Check if empty
  # @return [Boolean] true if no data
  def empty?
    @data.empty?
  end

  # Get size of data
  # @return [Integer] number of data entries
  def size
    @data.size
  end

  # Equality comparison
  # @param other [EventData] other event data
  # @return [Boolean] true if equal
  def ==(other)
    return false unless other.is_a?(EventData)

    @data == other.data &&
    @timestamp.to_i == other.timestamp.to_i &&
    @metadata == other.metadata
  end

  # Hash for collections
  # @return [Integer] hash value
  def hash
    [@data, @timestamp.to_i, @metadata].hash
  end

  # Convert to string for debugging
  # @return [String] string representation
  def to_s
    "EventData(#{@data.keys.join(', ')})"
  end

  private

  # Deep freeze data structures to prevent mutation
  # @param obj [Object] object to freeze
  # @return [Object] frozen object
  def deep_freeze(obj)
    case obj
    when Hash
      obj.each_value { |v| deep_freeze(v) }
      obj.freeze
    when Array
      obj.each { |item| deep_freeze(item) }
      obj.freeze
    when String, Symbol, Numeric, TrueClass, FalseClass, NilClass
      obj.freeze
    else
      obj
    end
  end

  # Validate data integrity
  # @raise [ArgumentError] if data is invalid
  def validate_data_integrity
    raise ArgumentError, 'Data must be a hash' unless @data.is_a?(Hash)
    raise ArgumentError, 'Metadata must be a hash' unless @metadata.is_a?(Hash)
    raise ArgumentError, 'Timestamp must be valid' unless @timestamp.is_a?(Time)
  end

  # Parse timestamp from various formats
  # @param timestamp [String, Time, nil] timestamp to parse
  # @return [Time, nil] parsed timestamp
  def self.parse_timestamp(timestamp)
    case timestamp
    when nil
      Time.current
    when Time
      timestamp
    when String
      Time.parse(timestamp)
    else
      Time.current
    end
  rescue ArgumentError
    Time.current
  end
end