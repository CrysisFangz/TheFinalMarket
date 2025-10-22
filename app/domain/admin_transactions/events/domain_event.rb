# frozen_string_literal: true

module AdminTransactions
  module Events
    # Base class for all domain events in the admin transactions domain
    # Implements immutable event sourcing patterns with comprehensive metadata
    #
    # @author Kilo Code Autonomous Agent
    # @version 2.0.0
    class DomainEvent
      # @param aggregate_id [String] ID of the aggregate this event belongs to
      # @param event_id [String] unique identifier for this event instance
      # @param occurred_at [Time] when the event occurred
      # @param metadata [Hash] additional contextual metadata
      def initialize(aggregate_id:, event_id: nil, occurred_at: nil, metadata: {})
        @aggregate_id = aggregate_id.dup.freeze
        @event_id = event_id || SecureRandom.uuid
        @occurred_at = occurred_at || Time.current
        @metadata = metadata.dup.freeze

        validate_base_data
      end

      # @return [String] ID of the aggregate this event belongs to
      attr_reader :aggregate_id

      # @return [String] unique identifier for this event instance
      attr_reader :event_id

      # @return [Time] when the event occurred
      attr_reader :occurred_at

      # @return [Hash] additional contextual metadata
      attr_reader :metadata

      # @return [String] name of the event class (for serialization)
      def event_type
        self.class.name.demodulize
      end

      # @return [Hash] complete event data for serialization
      def event_data
        raise NotImplementedError, 'Subclasses must implement event_data'
      end

      # @return [Hash] complete event for storage/transmission
      def to_h
        {
          event_id: @event_id,
          event_type: event_type,
          aggregate_id: @aggregate_id,
          occurred_at: @occurred_at,
          metadata: @metadata,
          data: event_data
        }
      end

      # @return [String] JSON representation of the event
      def to_json
        JSON.generate(to_h)
      end

      # @param other [DomainEvent] event to compare
      # @return [Boolean] true if events are equal
      def ==(other)
        return false unless other.is_a?(DomainEvent)

        @event_id == other.event_id
      end
      alias eql? ==

      # @return [Integer] hash code for use in collections
      def hash
        @event_id.hash
      end

      # @return [String] string representation of the event
      def to_s
        "#{event_type}(#{@aggregate_id} at #{@occurred_at})"
      end

      # @return [String] inspection string for debugging
      def inspect
        "DomainEvent(#{event_type} - #{@event_id})"
      end

      private

      # Validates base event data
      def validate_base_data
        raise ArgumentError, 'Aggregate ID is required' if @aggregate_id.blank?
        raise ArgumentError, 'Event ID is required' if @event_id.blank?
        raise ArgumentError, 'Occurred at is required' if @occurred_at.nil?
      end
    end
  end
end