# frozen_string_literal: true

module XrpWallet
  module Events
    # Base class for all domain events in the XRP wallet domain
    class DomainEvent
      # @param aggregate_id [String] Identifier of the aggregate that produced the event
      # @param event_type [String] Type/class name of the event
      # @param timestamp [Time] When the event occurred
      # @param metadata [Hash] Additional event data
      def initialize(aggregate_id:, event_type:, timestamp:, metadata: {})
        @aggregate_id = aggregate_id
        @event_type = event_type
        @timestamp = timestamp
        @metadata = metadata.dup.freeze

        freeze # Make immutable
      end

      # @return [String] Identifier of the aggregate that produced the event
      attr_reader :aggregate_id

      # @return [String] Type/class name of the event
      attr_reader :event_type

      # @return [Time] When the event occurred
      attr_reader :timestamp

      # @return [Hash] Additional event data
      attr_reader :metadata

      # @return [String] Unique event identifier
      def event_id
        @event_id ||= "#{event_type}:#{aggregate_id}:#{timestamp.to_i}:#{SecureRandom.hex(4)}"
      end

      # @return [Hash] Event data for serialization
      def to_h
        {
          event_id: event_id,
          aggregate_id: aggregate_id,
          event_type: event_type,
          timestamp: timestamp,
          metadata: metadata
        }
      end

      # @return [String] JSON representation of the event
      def to_json
        JSON.generate(to_h)
      end

      def ==(other)
        other.is_a?(DomainEvent) &&
        aggregate_id == other.aggregate_id &&
        event_type == other.event_type &&
        timestamp == other.timestamp &&
        metadata == other.metadata
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, aggregate_id, event_type, timestamp, metadata].hash
      end
    end
  end
end