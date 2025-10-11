class DecentralizedReview < ApplicationRecord
  belongs_to :product
  belongs_to :reviewer, class_name: 'User'
  
  has_many :review_verifications, dependent: :destroy
  
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :content, presence: true
  validates :blockchain_hash, presence: true, uniqueness: true
  
  scope :verified, -> { where(verified: true) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  
  # Create decentralized review
  def self.create_review(product:, reviewer:, rating:, content:, metadata: {})
    # Generate content hash
    content_hash = generate_content_hash(content, rating)
    
    review = create!(
      product: product,
      reviewer: reviewer,
      rating: rating,
      content: content,
      content_hash: content_hash,
      blockchain_hash: "0x#{SecureRandom.hex(32)}",
      metadata: metadata,
      verified: false
    )
    
    # Write to blockchain
    review.write_to_blockchain
    
    # Reward reviewer with tokens
    review.reward_reviewer
    
    review
  end
  
  # Write review to blockchain
  def write_to_blockchain
    # This would write to IPFS and blockchain
    ipfs_hash = upload_to_ipfs
    blockchain_tx = write_hash_to_blockchain(ipfs_hash)
    
    update!(
      ipfs_hash: ipfs_hash,
      blockchain_hash: blockchain_tx[:hash],
      blockchain_status: :confirmed,
      written_at: Time.current
    )
  end
  
  # Verify review authenticity
  def verify!
    # Verify on blockchain
    blockchain_data = fetch_from_blockchain
    
    if blockchain_data[:verified]
      update!(
        verified: true,
        verified_at: Time.current,
        verification_count: verification_count + 1
      )
    end
  end
  
  # Vote on review helpfulness
  def vote(user, helpful:)
    review_verifications.create!(
      user: user,
      helpful: helpful,
      verified_at: Time.current
    )
    
    if helpful
      increment!(:helpful_count)
    else
      increment!(:not_helpful_count)
    end
  end
  
  # Get helpfulness score
  def helpfulness_score
    total = helpful_count + not_helpful_count
    return 0 if total.zero?
    
    (helpful_count.to_f / total * 100).round(2)
  end
  
  # Check if review is tampered
  def tampered?
    current_hash = self.class.generate_content_hash(content, rating)
    current_hash != content_hash
  end
  
  # Get IPFS URL
  def ipfs_url
    return nil unless ipfs_hash
    
    "https://ipfs.io/ipfs/#{ipfs_hash}"
  end
  
  # Get blockchain explorer URL
  def blockchain_explorer_url
    return nil unless blockchain_hash
    
    "https://polygonscan.com/tx/#{blockchain_hash}"
  end
  
  # Reward reviewer with tokens
  def reward_reviewer
    token_amount = calculate_reward_amount
    
    loyalty_token = reviewer.loyalty_token || reviewer.create_loyalty_token
    loyalty_token.earn(
      token_amount,
      'Review reward',
      { review_id: id, product_id: product_id }
    )
  end
  
  # Get verification certificate
  def verification_certificate
    {
      review_id: id,
      product: product.name,
      reviewer: reviewer.username,
      rating: rating,
      content_hash: content_hash,
      blockchain_hash: blockchain_hash,
      ipfs_hash: ipfs_hash,
      verified: verified?,
      verified_at: verified_at,
      tampered: tampered?,
      verification_url: "#{ENV['APP_URL']}/reviews/verify/#{blockchain_hash}"
    }
  end
  
  private
  
  def self.generate_content_hash(content, rating)
    data = "#{content}#{rating}#{Time.current.to_i}"
    Digest::SHA256.hexdigest(data)
  end
  
  def upload_to_ipfs
    # This would upload to IPFS
    # For now, generate mock hash
    "Qm#{SecureRandom.hex(23)}"
  end
  
  def write_hash_to_blockchain(ipfs_hash)
    # This would write to blockchain
    # For now, return mock data
    {
      hash: "0x#{SecureRandom.hex(32)}",
      status: 'confirmed'
    }
  end
  
  def fetch_from_blockchain
    # This would query blockchain
    # For now, return mock data
    {
      verified: true,
      hash: blockchain_hash,
      timestamp: written_at
    }
  end
  
  def calculate_reward_amount
    # Base reward
    reward = 10
    
    # Bonus for verified purchase
    reward += 5 if reviewer.orders.where(product: product).exists?
    
    # Bonus for detailed review
    reward += 5 if content.length > 200
    
    # Bonus for photos
    reward += 10 if metadata['photos_count'].to_i > 0
    
    reward
  end
end

