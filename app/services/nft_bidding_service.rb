# frozen_string_literal: true

class NftBiddingService
  def initialize(nft)
    @nft = nft
  end

  def place_bid(bidder, amount_cents)
    @nft.nft_bids.create!(
      bidder: bidder,
      amount_cents: amount_cents,
      expires_at: 24.hours.from_now
    )
  end

  def accept_bid(bid)
    return false unless bid.active?

    transfer_service = NftTransferService.new(@nft)
    transfer_service.transfer_to(bid.bidder, bid.amount_cents)

    # Cancel other bids
    @nft.nft_bids.active.where.not(id: bid.id).update_all(status: :cancelled)

    bid.update!(status: :accepted)
  end
end