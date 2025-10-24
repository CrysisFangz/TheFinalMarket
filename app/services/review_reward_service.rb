class ReviewRewardService
  def self.reward_reviewer(review)
    token_amount = calculate_reward_amount(review)

    loyalty_token = review.reviewer.loyalty_token || review.reviewer.create_loyalty_token
    loyalty_token.earn(
      token_amount,
      'Review reward',
      { review_id: review.id, product_id: review.product_id }
    )
  end

  private

  def self.calculate_reward_amount(review)
    # Base reward
    reward = 10

    # Bonus for verified purchase
    reward += 5 if review.reviewer.orders.where(product: review.product).exists?

    # Bonus for detailed review
    reward += 5 if review.content.length > 200

    # Bonus for photos
    reward += 10 if review.metadata['photos_count'].to_i > 0

    reward
  end
end