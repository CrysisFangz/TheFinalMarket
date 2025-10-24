class NftTransferService
  attr_reader :nft

  def initialize(nft)
    @nft = nft
  end

  def transfer_to(new_owner, price_cents = 0)
    Rails.logger.info("Transferring NFT ID: #{nft.id} to owner ID: #{new_owner.id}")
    Nft.transaction do
      old_owner = nft.owner

      # Update NFT ownership
      nft.update!(owner: new_owner)

      # Record transfer
      nft.nft_transfers.create!(
        from_user: old_owner,
        to_user: new_owner,
        price_cents: price_cents,
        transfer_type: price_cents > 0 ? :sale : :transfer,
        transferred_at: Time.current
      )

      # Transfer on blockchain
      transfer_on_blockchain(new_owner.wallet_address)

      # Pay royalties if it's a sale
      pay_royalties(price_cents) if price_cents > 0

      Rails.logger.info("NFT ID: #{nft.id} transferred successfully")
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error transferring NFT ID: #{nft.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error transferring NFT ID: #{nft.id} - #{e.message}")
    raise
  end

  private

  def transfer_on_blockchain(to_address)
    # Integration with Web3 library
    # This would call smart contract transfer function
    nft.update!(transaction_hash: generate_transaction_hash)
  end

  def generate_transaction_hash
    "0x#{SecureRandom.hex(32)}"
  end

  def pay_royalties(sale_price)
    royalty_amount = (sale_price * nft.royalty_percentage / 100.0).to_i

    # Create royalty payment
    RoyaltyPayment.create!(
      nft: nft,
      recipient: nft.creator,
      amount_cents: royalty_amount,
      sale_price_cents: sale_price
    )
  end
end