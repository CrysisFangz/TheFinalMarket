class ReviewVotingService
  def self.vote(review, user, helpful:)
    review.review_verifications.create!(
      user: user,
      helpful: helpful,
      verified_at: Time.current
    )

    if helpful
      review.increment!(:helpful_count)
    else
      review.increment!(:not_helpful_count)
    end
  end
end