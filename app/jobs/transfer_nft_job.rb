# frozen_string_literal: true

class TransferNftJob < ApplicationJob
  queue_as :default

  def perform(nft_id, new_owner_id)
    nft = Nft.find(nft_id)
    new_owner = User.find(new_owner_id)
    transfer_on_blockchain(nft, new_owner)
  rescue ActiveRecord::RecordNotFound
    # Handle if NFT or user is deleted
  end

  private

  def transfer_on_blockchain(nft, new_owner)
    # Integration with Web3 library
    nft.update!(blockchain_status: :confirmed)
  rescue StandardError => e
    Rails.logger.error("Error transferring NFT on blockchain: #{e.message}")
    nft.update!(blockchain_status: :failed)
  end
end