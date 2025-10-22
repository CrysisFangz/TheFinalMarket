# frozen_string_literal: true

# Immutable Value Object for Channel Interaction Domain
#
# This value object represents an immutable, thread-safe snapshot of a channel interaction
# that cannot be modified after creation, ensuring referential transparency and eliminating
# race conditions in concurrent processing environments.
#
# Key Characteristics:
# - Immutable: Cannot be modified after creation
# - Thread-safe: Safe for concurrent access
# - Value-based equality: Equality based on content, not identity
# - Structural sharing: Efficient memory usage through immutable data structures
#
# @example
#   interaction = InteractionValueObject.new(
#     id: 123,
#     customer_id: 456,
#     channel_id: 789,
#     interaction_type: 'product_view',
#     interaction_data: { product_id: 101 },
#     occurred_at: Time.current,
#     value_score: 25,
#     context: { channel_name: 'Web Store' }
#   )
#
#   # Value-based equality
#   interaction == other_interaction # true if content is identical
#
#   # Immutable transformations return new instances
#   enriched = interaction.with_enriched_context(additional_data)
#
class InteractionValueObject
  include Comparable
  include Concurrent::ImmutableStruct

  # Define immutable fields with strict type validation
  fields = [
    :id,                          # Unique interaction identifier
    :customer_id,                 # Associated customer identifier
    :channel_id,                  # Associated sales channel identifier
    :interaction_type,            # Type of interaction (enum value)
    :interaction_data,            # Structured interaction payload (frozen)
    :occurred_at,                 # Timestamp when interaction occurred
    :value_score,                 # Calculated business value score
    :context,                     # Enriched context information (frozen)
    :correlation_id,              # Distributed tracing correlation ID
    :metadata                     # Additional structured metadata (frozen)
  ]

  immutable_struct fields: fields, validate: true

  # Custom initialization with enhanced validation and defaults
  def initialize(attributes = {})
    # Set defaults for optional fields
    attributes = attributes.with_defaults(
      correlation_id: generate_correlation_id,
      metadata: {},
      context: {}
    )

    # Deep freeze nested mutable objects
    attributes[:interaction_data] = deep_freeze(attributes[:interaction_data])
    attributes[:context] = deep_freeze(attributes[:context])
    attributes[:metadata] = deep_freeze(attributes[:metadata])

    # Validate required fields
    validate_required_fields!(attributes)

    super(attributes)
  end

  # Value-based equality comparison
  # @param other [InteractionValueObject] object to compare with
  # @return [Boolean] true if objects have identical content
  def ==(other)
    return false unless other.is_a?(InteractionValueObject)

    # Compare all significant fields for value equality
    id == other.id &&
    customer_id == other.customer_id &&
    channel_id == other.channel_id &&
    interaction_type == other.interaction_type &&
    interaction_data == other.interaction_data &&
    occurred_at == other.occurred_at &&
    value_score == other.value_score
  end

  # Hash code for use in hash-based collections
  # @return [Integer] hash code based on value content
  def hash
    [id, customer_id, channel_id, interaction_type, interaction_data, occurred_at, value_score].hash
  end

  # Comparable interface implementation
  # @param other [InteractionValueObject] object to compare with
  # @return [Integer] -1, 0, or 1 based on comparison
  def <=>(other)
    return nil unless other.is_a?(InteractionValueObject)

    # Primary sort by value score (descending), then by occurrence time
    result = other.value_score <=> value_score
    return result unless result.zero?

    occurred_at <=> other.occurred_at
  end

  # Immutable transformation methods that return new instances

  # Add enriched context information
  # @param additional_context [Hash] context data to merge
  # @return [InteractionValueObject] new instance with enriched context
  def with_enriched_context(additional_context)
    new_context = context.merge(additional_context).deep_freeze
    with(context: new_context)
  end

  # Update value score (e.g., after recalculation)
  # @param new_score [Integer] new value score
  # @return [InteractionValueObject] new instance with updated score
  def with_value_score(new_score)
    with(value_score: new_score)
  end

  # Add metadata
  # @param key [Symbol, String] metadata key
  # @param value [Object] metadata value
  # @return [InteractionValueObject] new instance with added metadata
  def with_metadata(key, value)
    new_metadata = metadata.merge(key => value).deep_freeze
    with(metadata: new_metadata)
  end

  # Check if interaction is high value
  # @return [Boolean] true if value score >= 50
  def high_value?
    value_score >= 50
  end

  # Check if interaction occurred recently
  # @param threshold [ActiveSupport::Duration] time threshold (default: 30 days)
  # @return [Boolean] true if interaction is within threshold
  def recent?(threshold = 30.days)
    occurred_at > threshold.ago
  end

  # Get interaction age in seconds
  # @return [Float] age in seconds since occurrence
  def age_in_seconds
    Time.current - occurred_at
  end

  # Convert to serializable hash for API responses
  # @param include_metadata [Boolean] whether to include metadata
  # @return [Hash] serializable representation
  def to_hash(include_metadata: false)
    hash = {
      id: id,
      customer_id: customer_id,
      channel_id: channel_id,
      interaction_type: interaction_type,
      interaction_data: interaction_data,
      occurred_at: occurred_at,
      value_score: value_score,
      context: context,
      correlation_id: correlation_id
    }

    hash[:metadata] = metadata if include_metadata
    hash
  end

  # Convert to JSON for external APIs
  # @return [String] JSON representation
  def to_json(**options)
    to_hash.to_json(options)
  end

  private

  # Generate unique correlation ID for distributed tracing
  # @return [String] UUID-based correlation identifier
  def generate_correlation_id
    "interaction_#{SecureRandom.uuid}"
  end

  # Deep freeze nested objects to ensure immutability
  # @param obj [Object] object to freeze
  # @return [Object] frozen object
  def deep_freeze(obj)
    case obj
    when Hash
      obj.each_value { |value| deep_freeze(value) }
      obj.freeze
    when Array
      obj.each { |item| deep_freeze(item) }
      obj.freeze
    when String, Symbol, Numeric, true, false, nil
      obj.freeze
    else
      obj.freeze if obj.respond_to?(:freeze)
    end
    obj
  end

  # Validate presence of required fields
  # @param attributes [Hash] attributes to validate
  # @raise [ArgumentError] if required fields are missing
  def validate_required_fields!(attributes)
    required_fields = [:id, :customer_id, :channel_id, :interaction_type, :interaction_data, :occurred_at]

    missing_fields = required_fields.select { |field| attributes[field].nil? }

    unless missing_fields.empty?
      raise ArgumentError, "Missing required fields: #{missing_fields.join(', ')}"
    end
  end

  # Enhanced string representation for debugging
  # @return [String] human-readable representation
  def inspect
    "#<#{self.class.name}:#{object_id} " \
    "id=#{id} " \
    "type=#{interaction_type} " \
    "score=#{value_score} " \
    "occurred_at=#{occurred_at}>"
  end
end