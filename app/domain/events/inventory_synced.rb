# frozen_string_literal: true

module Domain
  module Events
    class InventorySynced
      attr_reader :aggregate_id, :previous_quantity, :new_quantity, :sync_delta, :source, :version,
                  :timestamp, :correlation_id, :causation_id

      def initialize(aggregate_id:, previous_quantity:, new_quantity:, sync_delta:, source:, version:)
        @aggregate_id = aggregate_id
        @previous_quantity = previous_quantity
        @new_quantity = new_quantity
        @sync_delta = sync_delta
        @source = source
        @version = version
        @timestamp = Time.current
        @correlation_id = SecureRandom.uuid
        @causation_id = nil
      end

      def to_h
        {
          event_type: self.class.name,
          aggregate_id: aggregate_id,
          previous_quantity: previous_quantity,
          new_quantity: new_quantity,
          sync_delta: sync_delta,
          source: source,
          version: version,
          timestamp: timestamp,
          correlation_id: correlation_id,
          causation_id: causation_id
        }
      end
    end
  end
end