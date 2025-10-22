# frozen_string_literal: true

# Base class for all camera capture domain events
# Implements event sourcing patterns with immutable event data
class CameraCaptureEvent
  attr_reader :aggregate_id, :event_id, :timestamp, :version, :metadata

  # Create new domain event
  # @param aggregate_id [String] ID of the aggregate this event belongs to
  # @param event_id [String] unique event identifier
  # @param timestamp [Time] when the event occurred
  # @param version [Integer] aggregate version this event creates
  # @param metadata [Hash] additional event metadata
  def initialize(aggregate_id, event_id: nil, timestamp: nil, version: 1, metadata: {})
    @aggregate_id = aggregate_id
    @event_id = event_id || SecureRandom.uuid
    @timestamp = timestamp || Time.current
    @version = version
    @metadata = metadata.freeze

    validate!
  end

  # Get event type for serialization
  # @return [String] event type identifier
  def event_type
    self.class.name
  end

  # Get event data for serialization
  # @return [Hash] serializable event data
  def event_data
    {
      aggregate_id: @aggregate_id,
      event_id: @event_id,
      timestamp: @timestamp,
      version: @version,
      event_type: event_type,
      metadata: @metadata
    }
  end

  # Check if this event occurred after another event
  # @param other_event [CameraCaptureEvent] other event to compare
  # @return [Boolean] true if this event is after the other
  def after?(other_event)
    @timestamp > other_event.timestamp
  end

  # Check if this event occurred before another event
  # @param other_event [CameraCaptureEvent] other event to compare
  # @return [Boolean] true if this event is before the other
  def before?(other_event)
    @timestamp < other_event.timestamp
  end

  # Get time elapsed since this event
  # @return [Float] seconds since event
  def age_in_seconds
    Time.current - @timestamp
  end

  # Check if event is recent (within last 5 minutes)
  # @return [Boolean] true if recent
  def recent?
    age_in_seconds < 300
  end

  private

  # Validate event data integrity
  def validate!
    raise ArgumentError, 'Aggregate ID is required' if @aggregate_id.blank?
    raise ArgumentError, 'Event ID is required' if @event_id.blank?
    raise ArgumentError, 'Timestamp is required' unless @timestamp
    raise ArgumentError, 'Version must be positive' if @version <= 0
  end
end