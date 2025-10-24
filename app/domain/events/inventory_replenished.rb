# frozen_string_literal: true

module Domain
  module Events
    class InventoryReplenished
      attr_reader :aggregate_id, :amount, :source, :quantity_after, :version,
                  :timestamp, :correlation_id, :causation_id

      def initialize(aggregate_id:, amount:, source:, quantity_after:, version:)
        @aggregate_id = aggregate_id
        @amount = amount
        @source = source
        @quantity_after = quantity_after
        @version = version
        @timestamp = Time.current
        @correlation_id = SecureRandom.uuid
        @causation_id = nil
      end

      def to_h
        {
          event_type: self.class.name,
          aggregate_id: aggregate_id,
          amount: amount,
          source: source,
          quantity_after: quantity_after,
          version: version,
          timestamp: timestamp,
          correlation_id: correlation_id,
          causation_id: causation_id
        }
      end
    end
  end
end