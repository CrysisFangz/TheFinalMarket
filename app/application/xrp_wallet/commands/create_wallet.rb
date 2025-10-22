# frozen_string_literal: true

module XrpWallet
  module Commands
    # Command to create a new XRP wallet
    class CreateWallet
      # @param wallet_creation_service [Services::WalletCreationService] Domain service for wallet creation
      # @param event_publisher [EventPublisher] Publisher for domain events
      def initialize(wallet_creation_service:, event_publisher:)
        @wallet_creation_service = wallet_creation_service
        @event_publisher = event_publisher
      end

      # Executes the create wallet command
      # @param user_id [String] Unique user identifier
      # @param initial_balance [Numeric] Initial wallet balance (default: 0)
      # @return [Result] Command execution result
      def call(user_id:, initial_balance: 0)
        validate_params(user_id, initial_balance)

        wallet = wallet_creation_service.create_wallet(
          user_id: user_id,
          initial_balance: initial_balance
        )

        Result.success(wallet: wallet)
      rescue => e
        Result.failure(error: e.message)
      end

      private

      attr_reader :wallet_creation_service, :event_publisher

      def validate_params(user_id, initial_balance)
        raise ArgumentError, 'User ID is required' if user_id.nil? || user_id.empty?
        raise ArgumentError, 'Initial balance cannot be negative' if initial_balance.negative?
      end

      # Result object for command execution
      class Result
        # @param success [Boolean] Whether command succeeded
        # @param wallet [XrpWallet::Entities::XrpWallet, nil] Created wallet if successful
        # @param error [String, nil] Error message if failed
        def initialize(success:, wallet: nil, error: nil)
          @success = success
          @wallet = wallet
          @error = error
        end

        # @return [Boolean] Whether command succeeded
        def success?
          @success
        end

        # @return [Boolean] Whether command failed
        def failure?
          !@success
        end

        # @return [XrpWallet::Entities::XrpWallet, nil] Created wallet if successful
        def wallet
          @wallet
        end

        # @return [String, nil] Error message if failed
        def error
          @error
        end

        class << self
          # @param wallet [XrpWallet::Entities::XrpWallet] Created wallet
          # @return [Result] Success result
          def success(wallet:)
            new(success: true, wallet: wallet)
          end

          # @param error [String] Error message
          # @return [Result] Failure result
          def failure(error:)
            new(success: false, error: error)
          end
        end
      end
    end
  end
end