# frozen_string_literal: true

module Domain
  module Events
    class InventoryReserved
      attr_reader :aggregate_id, :amount, :order_id, :expires_at, :reserved_after, :version,
                  :timestamp, :correlation_id, :causation_id

      def initialize(aggregate_id:, amount:, order_id: nil, expires_at: nil, reserved_after:, version:)
        @aggregate_id = aggregate_id
        @amount = amount
        @order_id = order_id
        @expires_at = expires_at
        @reserved_after = reserved_after
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
          order_id: order_id,
          expires_at: expires_at,
          reserved_after: reserved_after,
          version: version,
          timestamp: timestamp,
          correlation_id: correlation_id,
          causation_id: causation_id
        }
      end
    end
  end
end