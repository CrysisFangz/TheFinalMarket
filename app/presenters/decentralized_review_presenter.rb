class DecentralizedReviewPresenter
  def initialize(review)
    @review = review
  end

  def as_json(options = {})
    {
      id: @review.id,
      product_id: @review.product_id,
      reviewer_id: @review.reviewer_id,
      rating: @review.rating,
      content: @review.content,
      content_hash: @review.content_hash,
      blockchain_hash: @review.blockchain_hash,
      ipfs_hash: @review.ipfs_hash,
      verified: @review.verified?,
      verified_at: @review.verified_at,
      verification_count: @review.verification_count,
      helpful_count: @review.helpful_count,
      not_helpful_count: @review.not_helpful_count,
      helpfulness_score: @review.helpfulness_score,
      tampered: @review.tampered?,
      ipfs_url: @review.ipfs_url,
      blockchain_explorer_url: @review.blockchain_explorer_url,
      verification_certificate: @review.verification_certificate,
      created_at: @review.created_at,
      updated_at: @review.updated_at
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end