class NftAnalyticsService
  attr_reader :nft

  def initialize(nft)
    @nft = nft
  end

  def rarity_score
    Rails.logger.debug("Getting rarity score for NFT ID: #{nft.id}")
    cache_key = "nft_rarity:#{nft.id}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      nft.metadata['rarity_score'] || calculate_rarity_score
    end
  end

  private

  def calculate_rarity_score
    # Simple rarity calculation based on traits
    traits = nft.metadata['traits'] || []
    return 0 if traits.empty?

    score = 0
    traits.each do |trait|
      # Rarer traits have higher scores
      trait_rarity = 100.0 / (trait['occurrence_rate'] || 50)
      score += trait_rarity
    end

    score.round(2)
  end
end