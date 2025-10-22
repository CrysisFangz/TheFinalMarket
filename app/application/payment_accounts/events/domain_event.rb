# frozen_string_literal: true

# Base Domain Event Class
# Immutable domain event with metadata and serialization
class DomainEvent
  attr_reader :aggregate_id, :event_id, :occurred_at, :correlation_id, :causation_id, :metadata

  def initialize(aggregate_id, event_id = nil, occurred_at = nil, correlation_id: nil, causation_id: nil, metadata: {})
    @aggregate_id = aggregate_id
    @event_id = event_id || SecureRandom.uuid
    @occurred_at = occurred_at || Time.current
    @correlation_id = correlation_id || @event_id
    @causation_id = causation_id
    @metadata = metadata

    validate!
  end

  def event_type
    raise NotImplementedError, 'Subclasses must implement event_type'
  end

  def aggregate_type
    raise NotImplementedError, 'Subclasses must implement aggregate_type'
  end

  def event_version
    1
  end

  def to_h
    {
      event_id: event_id,
      event_type: event_type,
      aggregate_id: aggregate_id,
      aggregate_type: aggregate_type,
      occurred_at: occurred_at.iso8601,
      event_version: event_version,
      correlation_id: correlation_id,
      causation_id: causation_id,
      metadata: metadata
    }
  end

  def to_json(options = {})
    to_h.to_json(options)
  end

  def with_metadata(additional_metadata)
    self.class.new(
      aggregate_id,
      event_id,
      occurred_at,
      correlation_id: correlation_id,
      causation_id: causation_id,
      metadata: metadata.merge(additional_metadata)
    )
  end

  def with_causation(causation_event)
    self.class.new(
      aggregate_id,
      event_id,
      occurred_at,
      correlation_id: correlation_id,
      causation_id: causation_event.event_id,
      metadata: metadata
    )
  end

  def ==(other)
    other.is_a?(self.class) &&
    other.event_id == event_id &&
    other.aggregate_id == aggregate_id
  end

  def eql?(other)
    self == other
  end

  def hash
    [self.class, event_id, aggregate_id].hash
  end

  private

  def validate!
    raise ValidationError, 'Aggregate ID is required' unless aggregate_id.present?
    raise ValidationError, 'Event ID is required' unless event_id.present?
    raise ValidationError, 'Occurred at is required' unless occurred_at.present?
  end
end