# frozen_string_literal: true

require_relative '../entities/xrp_wallet'
require_relative '../events/wallet_created'
require_relative '../value_objects/xrp_address'
require_relative '../value_objects/xrp_amount'

module XrpWallet
  module Services
    # Domain service for wallet creation business logic
    class WalletCreationService
      # @param wallet_repository [Repositories::WalletRepository] Repository for wallet persistence
      # @param event_publisher [EventPublisher] Publisher for domain events
      def initialize(wallet_repository:, event_publisher:)
        @wallet_repository = wallet_repository
        @event_publisher = event_publisher
      end

      # Creates a new XRP wallet for a user
      # @param user_id [String] Unique user identifier
      # @param initial_balance [Numeric] Initial wallet balance (default: 0)
      # @return [Entities::XrpWallet] Created wallet entity
      # @raise [ValidationError] if wallet creation fails
      def create_wallet(user_id:, initial_balance: 0)
        validate_creation_params(user_id, initial_balance)

        # Generate unique XRP address
        xrp_address = generate_unique_address

        # Create wallet entity
        wallet = Entities::XrpWallet.new(
          id: generate_wallet_id,
          user_id: user_id,
          xrp_address: xrp_address,
          balance: XrpAmount.new(initial_balance),
          status: Entities::XrpWallet::STATUSES[:active]
        )

        # Persist wallet
        persisted_wallet = wallet_repository.save(wallet)

        # Publish domain event
        event = Events::WalletCreated.new(
          wallet_id: persisted_wallet.id,
          user_id: user_id,
          xrp_address: xrp_address.to_s,
          initial_balance: initial_balance
        )

        event_publisher.publish(event)

        persisted_wallet
      end

      private

      attr_reader :wallet_repository, :event_publisher

      def validate_creation_params(user_id, initial_balance)
        raise ArgumentError, 'User ID cannot be nil or empty' if user_id.nil? || user_id.empty?
        raise ArgumentError, 'Initial balance cannot be negative' if initial_balance.negative?
      end

      def generate_unique_address
        loop do
          # Generate random XRP address (simplified for this example)
          # In production, use proper XRP address generation
          address_string = "r#{SecureRandom.hex(16).upcase[0..31]}"

          # Check if address is already in use
          break address_string unless wallet_repository.address_exists?(address_string)
        end
      end

      def generate_wallet_id
        "wallet_#{SecureRandom.uuid}"
      end
    end
  end
end