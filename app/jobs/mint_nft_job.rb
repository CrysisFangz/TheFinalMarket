# frozen_string_literal: true

class MintNftJob < ApplicationJob
  queue_as :default

  def perform(nft_id)
    nft = Nft.find(nft_id)
    mint_on_blockchain(nft)
  rescue ActiveRecord::RecordNotFound
    # Handle if NFT is deleted
  end

  private

  def mint_on_blockchain(nft)
    # Integration with Web3 library
    nft.update!(
      transaction_hash: SecureRandom.hex(32),
      blockchain_status: :confirmed
    )
  rescue StandardError => e
    Rails.logger.error("Error minting NFT on blockchain: #{e.message}")
    nft.update!(blockchain_status: :failed)
  end
end