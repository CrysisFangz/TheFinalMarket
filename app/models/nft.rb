class Nft < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :creator, class_name: 'User'
  belongs_to :owner, class_name: 'User'
  
  has_many :nft_transfers, dependent: :destroy
  has_many :nft_bids, dependent: :destroy
  
  has_one_attached :digital_asset
  has_one_attached :preview_image
  
  validates :token_id, presence: true, uniqueness: true
  validates :contract_address, presence: true
  validates :name, presence: true
  validates :nft_type, presence: true
  validates :blockchain, presence: true
  validates :metadata, allow_nil: true
  validates :royalty_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  
  scope :for_sale, -> { where(for_sale: true) }
  scope :by_type, ->(type) { where(nft_type: type) }
  scope :by_creator, ->(user) { where(creator: user) }
  scope :by_owner, ->(user) { where(owner: user) }
  
  # NFT types
  enum nft_type: {
    digital_art: 0,
    collectible: 1,
    limited_edition_product: 2,
    membership_pass: 3,
    event_ticket: 4,
    loyalty_token: 5,
    certificate: 6
  }
  
  # Blockchain networks
  enum blockchain: {
    ethereum: 0,
    polygon: 1,
    binance_smart_chain: 2,
    solana: 3
  }
  
  # Mint NFT
  def self.mint(creator:, name:, description:, nft_type:, metadata: {})
    NftMintingService.mint(creator: creator, name: name, description: description, nft_type: nft_type, metadata: metadata)
  end
  
  # Transfer NFT
  def transfer_to(new_owner, price_cents = 0)
    NftTransferService.new(self).transfer_to(new_owner, price_cents)
  end
  
  # List for sale
  def list_for_sale(price_cents)
    update!(
      for_sale: true,
      sale_price_cents: price_cents,
      listed_at: Time.current
    )
  end
  
  # Remove from sale
  def unlist
    update!(
      for_sale: false,
      sale_price_cents: nil,
      listed_at: nil
    )
  end
  
  # Place bid
  def place_bid(bidder, amount_cents)
    NftBiddingService.new(self).place_bid(bidder, amount_cents)
  end

  # Accept bid
  def accept_bid(bid)
    NftBiddingService.new(self).accept_bid(bid)
  end
  
  # Get metadata URI
  def metadata_uri
    "ipfs://#{ipfs_hash}" if ipfs_hash.present?
  end
  
  # Get OpenSea URL
  def opensea_url
    "https://opensea.io/assets/#{blockchain}/#{contract_address}/#{token_id}"
  end
  
  # Get rarity score
  def rarity_score
    cache_key = "nft_rarity:#{id}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      metadata['rarity_score'] || calculate_rarity_score
    end
  end
  
  # Verify authenticity
  def verify_authenticity
    # Verify on blockchain
    blockchain_data = fetch_blockchain_data
    
    {
      verified: blockchain_data[:owner] == owner.wallet_address,
      contract_verified: blockchain_data[:contract] == contract_address,
      token_exists: blockchain_data[:exists],
      metadata_match: blockchain_data[:metadata_uri] == metadata_uri
    }
  end
  
  private
  
  def self.generate_token_id
    loop do
      token_id = SecureRandom.hex(32)
      break token_id unless exists?(token_id: token_id)
    end
  end
  
  def self.get_contract_address(nft_type)
    # Different contracts for different NFT types
    {
      digital_art: ENV['NFT_ART_CONTRACT'],
      collectible: ENV['NFT_COLLECTIBLE_CONTRACT'],
      limited_edition_product: ENV['NFT_PRODUCT_CONTRACT'],
      membership_pass: ENV['NFT_MEMBERSHIP_CONTRACT'],
      event_ticket: ENV['NFT_TICKET_CONTRACT'],
      loyalty_token: ENV['NFT_LOYALTY_CONTRACT'],
      certificate: ENV['NFT_CERTIFICATE_CONTRACT']
    }[nft_type.to_sym] || ENV['NFT_DEFAULT_CONTRACT']
  end
  
  def self.mint_on_blockchain(nft)
    # Integration with Web3 library
    # This would call smart contract mint function
    # For now, simulate with transaction hash
    nft.update!(
      transaction_hash: SecureRandom.hex(32),
      blockchain_status: :confirmed
    )
  end
  
  def transfer_on_blockchain(to_address)
    # Integration with Web3 library
    # This would call smart contract transfer function
    generate_transaction_hash
  end
  
  def generate_transaction_hash
    "0x#{SecureRandom.hex(32)}"
  end
  
  def pay_royalties(sale_price)
    royalty_amount = (sale_price * royalty_percentage / 100.0).to_i
    
    # Create royalty payment
    RoyaltyPayment.create!(
      nft: self,
      recipient: creator,
      amount_cents: royalty_amount,
      sale_price_cents: sale_price
    )
  end
  
  def calculate_rarity_score
    # Simple rarity calculation based on traits
    traits = metadata['traits'] || []
    return 0 if traits.empty?
    
    score = 0
    traits.each do |trait|
      # Rarer traits have higher scores
      trait_rarity = 100.0 / (trait['occurrence_rate'] || 50)
      score += trait_rarity
    end
    
    score.round(2)
  end
  
  def fetch_blockchain_data
    # This would query the blockchain
    # For now, return mock data
    {
      owner: owner.wallet_address,
      contract: contract_address,
      exists: true,
      metadata_uri: metadata_uri
    }
  end
end

