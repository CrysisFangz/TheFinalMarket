class DailyChallengeService
  def self.generate_for_date(date = Date.current)
    return if DailyChallenge.for_date(date).exists?

    challenges = [
      {
        title: "Window Shopper",
        description: "Browse 10 different products",
        challenge_type: :browse_products,
        target_value: 10,
        reward_points: 50,
        reward_coins: 10,
        difficulty: :easy
      },
      {
        title: "Wishlist Builder",
        description: "Add 3 items to your wishlist",
        challenge_type: :add_to_wishlist,
        target_value: 3,
        reward_points: 75,
        reward_coins: 15,
        difficulty: :easy
      },
      {
        title: "Review Master",
        description: "Leave a detailed review on a purchased item",
        challenge_type: :leave_review,
        target_value: 1,
        reward_points: 100,
        reward_coins: 25,
        difficulty: :medium
      },
      {
        title: "Social Butterfly",
        description: "Share 2 products with friends",
        challenge_type: :share_product,
        target_value: 2,
        reward_points: 60,
        reward_coins: 12,
        difficulty: :easy
      }
    ]

    selected_challenges = challenges.sample(3)

    selected_challenges.each do |challenge_data|
      DailyChallenge.create!(
        challenge_data.merge(
          active_date: date,
          expires_at: date.end_of_day,
          active: true
        )
      )
    end
  end

  def complete_challenge(challenge, user)
    user_challenge = challenge.user_daily_challenges.find_or_create_by!(user: user)
    user_challenge.update!(
      completed: true,
      completed_at: Time.current
    )

    # Award rewards
    user.increment!(:points, challenge.reward_points) if challenge.reward_points > 0
    user.increment!(:coins, challenge.reward_coins) if challenge.reward_coins > 0

    # Update streak
    user.update_challenge_streak!

    # Send notification
    Notification.create!(
      recipient: user,
      notifiable: challenge,
      notification_type: 'challenge_completed',
      title: "Challenge Completed: #{challenge.title}!",
      message: "You've earned #{challenge.reward_points} points and #{challenge.reward_coins} coins!",
      data: {
        points: challenge.reward_points,
        coins: challenge.reward_coins,
        difficulty: challenge.difficulty
      }
    )

    # Broadcast completion
    challenge.broadcast_completion(user)
  end

  def update_progress(challenge, user, increment = 1)
    user_challenge = challenge.user_daily_challenges.find_or_create_by!(user: user)
    user_challenge.increment!(:current_value, increment)

    if user_challenge.current_value >= challenge.target_value && !user_challenge.completed?
      complete_challenge(challenge, user)
    end

    user_challenge
  end
end