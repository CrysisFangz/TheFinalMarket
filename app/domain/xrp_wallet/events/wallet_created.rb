# frozen_string_literal: true

module XrpWallet
  module Events
    # Domain event representing wallet creation
    class WalletCreated < DomainEvent
      # @param wallet_id [String] Unique wallet identifier
      # @param user_id [String] Associated user identifier
      # @param xrp_address [String] XRP wallet address
      # @param initial_balance [BigDecimal] Initial wallet balance
      # @param metadata [Hash] Additional event metadata
      def initialize(wallet_id:, user_id:, xrp_address:, initial_balance: 0, metadata: {})
        super(
          aggregate_id: wallet_id,
          event_type: self.class.name,
          timestamp: Time.current,
          metadata: metadata.merge(
            user_id: user_id,
            xrp_address: xrp_address,
            initial_balance: initial_balance
          )
        )

        freeze
      end

      # @return [String] Unique wallet identifier
      def wallet_id
        aggregate_id
      end

      # @return [String] Associated user identifier
      def user_id
        metadata[:user_id]
      end

      # @return [String] XRP wallet address
      def xrp_address
        metadata[:xrp_address]
      end

      # @return [BigDecimal] Initial wallet balance
      def initial_balance
        metadata[:initial_balance] || 0
      end
    end
  end
end