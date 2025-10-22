# frozen_string_literal: true

require_relative '../../../domain/xrp_wallet/repositories/wallet_repository'
require_relative '../../../domain/xrp_wallet/entities/xrp_wallet'
require_relative '../../../domain/xrp_wallet/value_objects/xrp_address'
require_relative '../../../domain/xrp_wallet/value_objects/xrp_amount'

module XrpWallet
  module Infrastructure
    module Repositories
      # ActiveRecord implementation of wallet repository
      class ActiveRecordWalletRepository < Domain::Repositories::WalletRepository
        # @param model_class [Class] ActiveRecord model class (default: ::XrpWallet)
        def initialize(model_class: ::XrpWallet)
          @model_class = model_class
        end

        # @param id [String] Unique wallet identifier
        # @return [Domain::Entities::XrpWallet, nil] Wallet entity or nil if not found
        def find_by_id(id)
          record = model_class.find_by(id: id)
          return nil if record.nil?

          to_entity(record)
        end

        # @param user_id [String] User identifier
        # @return [Array<Domain::Entities::XrpWallet>] Collection of user's wallets
        def find_by_user_id(user_id)
          records = model_class.where(user_id: user_id)
          records.map { |record| to_entity(record) }
        end

        # @param xrp_address [String] XRP address
        # @return [Domain::Entities::XrpWallet, nil] Wallet entity or nil if not found
        def find_by_xrp_address(xrp_address)
          record = model_class.find_by(xrp_address: xrp_address)
          return nil if record.nil?

          to_entity(record)
        end

        # @param wallet [Domain::Entities::XrpWallet] Wallet entity to save
        # @return [Domain::Entities::XrpWallet] Saved wallet entity
        def save(wallet)
          record = model_class.find_or_initialize_by(id: wallet.id)

          record.user_id = wallet.user_id
          record.xrp_address = wallet.xrp_address.to_s
          record.status = wallet.status
          record.balance_xrp = wallet.balance.to_s
          record.created_at = wallet.created_at
          record.updated_at = wallet.updated_at

          record.save!

          to_entity(record)
        end

        # @param wallet_id [String] Unique wallet identifier
        # @return [Boolean] True if wallet was deleted
        def delete(wallet_id)
          model_class.destroy_by(id: wallet_id).any?
        end

        # @return [Array<Domain::Entities::XrpWallet>] All wallets
        def all
          model_class.all.map { |record| to_entity(record) }
        end

        # @param wallet_id [String] Unique wallet identifier
        # @return [Boolean] True if wallet exists
        def exists?(wallet_id)
          model_class.exists?(id: wallet_id)
        end

        # @param xrp_address [String] XRP address
        # @return [Boolean] True if address is already in use
        def address_exists?(xrp_address)
          model_class.exists?(xrp_address: xrp_address)
        end

        private

        attr_reader :model_class

        def to_entity(record)
          Domain::Entities::XrpWallet.new(
            id: record.id,
            user_id: record.user_id,
            xrp_address: record.xrp_address,
            status: record.status,
            balance: record.balance_xrp,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end