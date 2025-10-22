# frozen_string_literal: true

module XrpWallet
  module Events
    # Domain event representing payment initiation
    class PaymentInitiated < DomainEvent
      # @param wallet_id [String] Source wallet identifier
      # @param payment_id [String] Unique payment identifier
      # @param amount [BigDecimal] Payment amount in XRP
      # @param destination_address [String] Destination XRP address
      # @param order_id [String, nil] Associated order identifier
      # @param metadata [Hash] Additional event metadata
      def initialize(wallet_id:, payment_id:, amount:, destination_address:, order_id: nil, metadata: {})
        super(
          aggregate_id: wallet_id,
          event_type: self.class.name,
          timestamp: Time.current,
          metadata: metadata.merge(
            payment_id: payment_id,
            amount: amount,
            destination_address: destination_address,
            order_id: order_id
          )
        )

        freeze
      end

      # @return [String] Source wallet identifier
      def wallet_id
        aggregate_id
      end

      # @return [String] Unique payment identifier
      def payment_id
        metadata[:payment_id]
      end

      # @return [BigDecimal] Payment amount in XRP
      def amount
        metadata[:amount]
      end

      # @return [String] Destination XRP address
      def destination_address
        metadata[:destination_address]
      end

      # @return [String, nil] Associated order identifier
      def order_id
        metadata[:order_id]
      end
    end
  end
end