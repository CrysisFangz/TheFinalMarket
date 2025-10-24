class DecentralizedReviewService
  def self.create_review(product:, reviewer:, rating:, content:, metadata: {})
    # Generate content hash
    content_hash = generate_content_hash(content, rating)

    review = DecentralizedReview.create!(
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

  private

  def self.generate_content_hash(content, rating)
    data = "#{content}#{rating}#{Time.current.to_i}"
    Digest::SHA256.hexdigest(data)
  end
end