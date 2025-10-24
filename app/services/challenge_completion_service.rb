class ChallengeCompletionService
  def self.complete_for(challenge, user)
    return false if challenge.completed_by?(user) && !challenge.repeatable?

    completion = challenge.challenge_completions.create!(
      user: user,
      completed_at: Time.current
    )

    # Award points
    challenge.seasonal_event.award_points(user, challenge.points_reward, "Challenge: #{challenge.name}")

    # Award bonus rewards
    award_bonus_rewards(challenge, user)

    # Increment completion count
    challenge.increment!(:completion_count)

    # Notify user
    notify_completion(challenge, user)

    completion
  end

  private

  def self.award_bonus_rewards(challenge, user)
    return unless challenge.bonus_coins > 0
    user.increment!(:coins, challenge.bonus_coins)
  end

  def self.notify_completion(challenge, user)
    ChallengeNotificationService.notify(
      user: user,
      title: "Challenge Completed: #{challenge.name}!",
      message: challenge.description,
      resource: challenge,
      data: { points: challenge.points_reward, bonus_coins: challenge.bonus_coins }
    )
  end
end