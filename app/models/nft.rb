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
  
  # Delegated to NftMintingService
  def self.mint(creator:, name:, description:, nft_type:, metadata: {})
    NftMintingService.mint(creator: creator, name: name, description: description, nft_type: nft_type, metadata: metadata)
  end
  
  # Delegated to NftTransferService
  def transfer_to(new_owner, price_cents = 0)
    @transfer_service ||= NftTransferService.new(self)
    @transfer_service.transfer_to(new_owner, price_cents)
  end
  
  # Delegated to NftSaleService
  def list_for_sale(price_cents)
    @sale_service ||= NftSaleService.new(self)
    @sale_service.list_for_sale(price_cents)
  end

  def unlist
    @sale_service ||= NftSaleService.new(self)
    @sale_service.unlist
  end
  
  # Delegated to NftBiddingService
  def place_bid(bidder, amount_cents)
    @bidding_service ||= NftBiddingService.new(self)
    @bidding_service.place_bid(bidder, amount_cents)
  end

  def accept_bid(bid)
    @bidding_service ||= NftBiddingService.new(self)
    @bidding_service.accept_bid(bid)
  end
  
  # Delegated to NftBlockchainService and NftAnalyticsService
  def metadata_uri
    @blockchain_service ||= NftBlockchainService.new(self)
    @blockchain_service.metadata_uri
  end

  def opensea_url
    @blockchain_service ||= NftBlockchainService.new(self)
    @blockchain_service.opensea_url
  end

  def rarity_score
    @analytics_service ||= NftAnalyticsService.new(self)
    @analytics_service.rarity_score
  end

  def verify_authenticity
    @blockchain_service ||= NftBlockchainService.new(self)
    @blockchain_service.verify_authenticity
  end
  
  private

  # All private methods are now handled in respective services
end

