class DecentralizedReview < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :product
  belongs_to :reviewer, class_name: 'User'

  has_many :review_verifications, dependent: :destroy

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :content, presence: true
  validates :blockchain_hash, presence: true, uniqueness: true

  scope :verified, -> { where(verified: true) }
  scope :by_rating, ->(rating) { where(rating: rating) }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Create decentralized review
  def self.create_review(product:, reviewer:, rating:, content:, metadata: {})
    DecentralizedReviewService.create_review(
      product: product,
      reviewer: reviewer,
      rating: rating,
      content: content,
      metadata: metadata
    )
  end

  # Write review to blockchain
  def write_to_blockchain
    with_retry do
      self.class.with_circuit_breaker(name: 'blockchain_api') do
        ipfs_hash = BlockchainService.upload_to_ipfs("#{content}#{rating}")
        blockchain_tx = BlockchainService.write_hash_to_blockchain(ipfs_hash)

        update!(
          ipfs_hash: ipfs_hash,
          blockchain_hash: blockchain_tx[:hash],
          blockchain_status: :confirmed,
          written_at: Time.current
        )
      end
    end
  end

  # Verify review authenticity
  def verify!
    with_retry do
      ReviewVerificationService.verify_review(self)
    end
  end

  # Vote on review helpfulness
  def vote(user, helpful:)
    ReviewVotingService.vote(self, user, helpful)
  end

  # Get helpfulness score
  def helpfulness_score
    Rails.cache.fetch("review:#{id}:helpfulness_score", expires_in: 1.hour) do
      total = helpful_count + not_helpful_count
      return 0 if total.zero?

      (helpful_count.to_f / total * 100).round(2)
    end
  end

  # Check if review is tampered
  def tampered?
    Rails.cache.fetch("review:#{id}:tampered", expires_in: 30.minutes) do
      current_hash = self.class.generate_content_hash(content, rating)
      current_hash != content_hash
    end
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
    ReviewRewardService.reward_reviewer(self)
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

  def publish_created_event
    EventPublisher.publish('decentralized_review.created', {
      review_id: id,
      product_id: product_id,
      reviewer_id: reviewer_id,
      rating: rating,
      blockchain_hash: blockchain_hash,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('decentralized_review.updated', {
      review_id: id,
      product_id: product_id,
      reviewer_id: reviewer_id,
      rating: rating,
      verified: verified?,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('decentralized_review.destroyed', {
      review_id: id,
      product_id: product_id,
      reviewer_id: reviewer_id,
      rating: rating
    })
  end

  def self.generate_content_hash(content, rating)
    data = "#{content}#{rating}#{Time.current.to_i}"
    Digest::SHA256.hexdigest(data)
  end
end