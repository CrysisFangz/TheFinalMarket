class UserDailyChallengeCalculator
  def self.progress_percentage(user_daily_challenge)
    Rails.cache.fetch("user_daily_challenge_progress_#{user_daily_challenge.id}", expires_in: 1.hour) do
      return 100.0 if user_daily_challenge.completed?
      target = user_daily_challenge.daily_challenge.target_value.to_f
      current = user_daily_challenge.current_value.to_f
      return 0.0 if target.zero?
      ((current / target) * 100).round(2).clamp(0, 100)
    end
  end

  def self.remaining(user_daily_challenge)
    Rails.cache.fetch("user_daily_challenge_remaining_#{user_daily_challenge.id}", expires_in: 1.hour) do
      [user_daily_challenge.daily_challenge.target_value - user_daily_challenge.current_value, 0].max
    end
  end
end