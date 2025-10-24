# frozen_string_literal: true

class NftTransferService
  def initialize(nft)
    @nft = nft
  end

  def transfer_to(new_owner, price_cents = 0)
    return false if @nft.owner == new_owner

    ActiveRecord::Base.transaction do
      # Create transfer record
      transfer = @nft.nft_transfers.create!(
        from_user: @nft.owner,
        to_user: new_owner,
        price_cents: price_cents,
        transaction_hash: generate_transaction_hash,
        transferred_at: Time.current
      )

      # Update ownership
      @nft.update!(
        owner: new_owner,
        last_sale_price_cents: price_cents > 0 ? price_cents : @nft.last_sale_price_cents,
        transfer_count: @nft.transfer_count + 1
      )

      # Schedule async blockchain transfer
      TransferNftJob.perform_later(@nft.id, new_owner.id)

      # Pay royalties
      if price_cents > 0 && @nft.royalty_percentage > 0
        pay_royalties(price_cents)
      end

      transfer
    end
  end

  private

  def generate_transaction_hash
    "0x#{SecureRandom.hex(32)}"
  end

  def pay_royalties(sale_price)
    royalty_amount = (sale_price * @nft.royalty_percentage / 100.0).to_i

    RoyaltyPayment.create!(
      nft: @nft,
      recipient: @nft.creator,
      amount_cents: royalty_amount,
      sale_price_cents: sale_price
    )
  end
end