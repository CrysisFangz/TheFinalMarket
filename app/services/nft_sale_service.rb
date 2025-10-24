class NftSaleService
  attr_reader :nft

  def initialize(nft)
    @nft = nft
  end

  def list_for_sale(price_cents)
    Rails.logger.info("Listing NFT ID: #{nft.id} for sale at #{price_cents} cents")
    nft.update!(
      for_sale: true,
      sale_price_cents: price_cents,
      listed_at: Time.current
    )
    Rails.logger.info("NFT ID: #{nft.id} listed for sale successfully")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error listing NFT ID: #{nft.id} for sale - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error listing NFT ID: #{nft.id} for sale - #{e.message}")
    raise
  end

  def unlist
    Rails.logger.info("Unlisting NFT ID: #{nft.id} from sale")
    nft.update!(
      for_sale: false,
      sale_price_cents: nil,
      listed_at: nil
    )
    Rails.logger.info("NFT ID: #{nft.id} unlisted successfully")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error unlisting NFT ID: #{nft.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error unlisting NFT ID: #{nft.id} - #{e.message}")
    raise
  end
end