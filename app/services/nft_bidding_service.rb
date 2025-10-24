class NftBiddingService
  attr_reader :nft

  def initialize(nft)
    @nft = nft
  end

  def place_bid(bidder, amount_cents)
    Rails.logger.info("Placing bid of #{amount_cents} cents on NFT ID: #{nft.id} by user ID: #{bidder.id}")
    bid = nft.nft_bids.create!(
      bidder: bidder,
      amount_cents: amount_cents,
      status: :active,
      expires_at: 7.days.from_now,
      placed_at: Time.current
    )
    Rails.logger.info("Bid placed successfully on NFT ID: #{nft.id}")
    bid
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error placing bid on NFT ID: #{nft.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error placing bid on NFT ID: #{nft.id} - #{e.message}")
    raise
  end

  def accept_bid(bid)
    Rails.logger.info("Accepting bid ID: #{bid.id} on NFT ID: #{nft.id}")
    Nft.transaction do
      bid.update!(status: :accepted, accepted_at: Time.current)

      # Transfer NFT to bidder
      NftTransferService.new(nft).transfer_to(bid.bidder, bid.amount_cents)

      # Cancel other bids
      nft.nft_bids.where.not(id: bid.id).update_all(status: :cancelled)

      Rails.logger.info("Bid ID: #{bid.id} accepted successfully")
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error accepting bid ID: #{bid.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error accepting bid ID: #{bid.id} - #{e.message}")
    raise
  end
end