# frozen_string_literal: true

module Charity
  module Events
    # Base class for all domain events in the charity domain
    # Implements event sourcing patterns with immutable event data
    class DomainEvent
      attr_reader :event_type, :occurred_at, :event_data, :event_id, :correlation_id, :causation_id

      # Initialize a new domain event
      # @param event_type [Symbol] type of event
      # @param occurred_at [Time] when the event occurred
      # @param event_data [Hash] event payload data
      def initialize(event_type, occurred_at = Time.current, event_data = {})
        @event_type = event_type
        @occurred_at = occurred_at
        @event_data = event_data.deep_symbolize_keys.freeze
        @event_id = generate_event_id
        @correlation_id = event_data[:correlation_id] || generate_correlation_id
        @causation_id = event_data[:causation_id] || @event_id
      end

      # Create event with correlation tracking (for distributed transactions)
      # @param event_type [Symbol] type of event
      # @param correlation_id [String] correlation identifier
      # @param causation_id [String] causation identifier
      # @param event_data [Hash] event payload
      def self.with_correlation(event_type, correlation_id, causation_id = nil, **event_data)
        new(event_type, Time.current, event_data.merge(
          correlation_id: correlation_id,
          causation_id: causation_id || generate_event_id
        ))
      end

      # Serialize event for storage
      # @return [Hash] serializable event data
      def to_h
        {
          event_id: @event_id,
          event_type: @event_type,
          occurred_at: @occurred_at.iso8601,
          event_data: @event_data,
          correlation_id: @correlation_id,
          causation_id: @causation_id
        }
      end

      # Serialize for JSON storage
      # @return [Hash] JSON-serializable data
      def as_json
        to_h.merge(
          event_data: @event_data.merge(timestamp: @occurred_at)
        )
      end

      # Event metadata for debugging and monitoring
      # @return [Hash] metadata
      def metadata
        @event_data[:metadata] || {}
      end

      # Check if this event is part of a correlation chain
      # @return [Boolean] true if correlated
      def correlated?
        !@correlation_id.nil? && @correlation_id != @event_id
      end

      # Get aggregate ID that this event applies to
      # @return [String] aggregate identifier
      def aggregate_id
        @event_data[:aggregate_id] || @event_data[:charity_id]
      end

      # Equality comparison for event deduplication
      # @param other [DomainEvent] other event
      # @return [Boolean] true if equal
      def ==(other)
        return false unless other.is_a?(DomainEvent)

        @event_id == other.event_id
      end

      # Hash for use in collections
      # @return [Integer] hash value
      def hash
        @event_id.hash
      end

      # String representation for logging
      # @return [String] string representation
      def to_s
        "#{@event_type} at #{@occurred_at} (#{@event_id})"
      end

      # Inspect for debugging
      # @return [String] debug string
      def inspect
        "#<#{self.class.name}:#{@event_type} #{@event_id}>"
      end

      private

      # Generate unique event identifier
      # @return [String] unique event ID
      def generate_event_id
        "#{@event_type}_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
      end

      # Generate correlation identifier for distributed transactions
      # @return [String] correlation ID
      def generate_correlation_id
        "correlation_#{SecureRandom.hex(8)}"
      end
    end
  end
end