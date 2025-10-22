# frozen_string_literal: true

module XrpWallet
  module Repositories
    # Repository interface for XRP wallet data access
    class WalletRepository
      # @abstract
      # @param id [String] Unique wallet identifier
      # @return [Entities::XrpWallet, nil] Wallet entity or nil if not found
      def find_by_id(id)
        raise NotImplementedError, 'Subclasses must implement #find_by_id'
      end

      # @abstract
      # @param user_id [String] User identifier
      # @return [Array<Entities::XrpWallet>] Collection of user's wallets
      def find_by_user_id(user_id)
        raise NotImplementedError, 'Subclasses must implement #find_by_user_id'
      end

      # @abstract
      # @param xrp_address [String] XRP address
      # @return [Entities::XrpWallet, nil] Wallet entity or nil if not found
      def find_by_xrp_address(xrp_address)
        raise NotImplementedError, 'Subclasses must implement #find_by_xrp_address'
      end

      # @abstract
      # @param wallet [Entities::XrpWallet] Wallet entity to save
      # @return [Entities::XrpWallet] Saved wallet entity
      def save(wallet)
        raise NotImplementedError, 'Subclasses must implement #save'
      end

      # @abstract
      # @param wallet_id [String] Unique wallet identifier
      # @return [Boolean] True if wallet was deleted
      def delete(wallet_id)
        raise NotImplementedError, 'Subclasses must implement #delete'
      end

      # @abstract
      # @return [Array<Entities::XrpWallet>] All wallets
      def all
        raise NotImplementedError, 'Subclasses must implement #all'
      end

      # @abstract
      # @param wallet_id [String] Unique wallet identifier
      # @return [Boolean] True if wallet exists
      def exists?(wallet_id)
        raise NotImplementedError, 'Subclasses must implement #exists?'
      end

      # @abstract
      # @param xrp_address [String] XRP address
      # @return [Boolean] True if address is already in use
      def address_exists?(xrp_address)
        raise NotImplementedError, 'Subclasses must implement #address_exists?'
      end
    end
  end
end