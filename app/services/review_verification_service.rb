class ReviewVerificationService
  def self.verify_review(review)
    blockchain_data = BlockchainService.fetch_from_blockchain(review.blockchain_hash)

    if blockchain_data[:verified]
      review.update!(
        verified: true,
        verified_at: Time.current,
        verification_count: review.verification_count + 1
      )
    end
  end
end