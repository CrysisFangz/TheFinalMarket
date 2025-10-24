class ParticipationService
  def self.get_completed_challenges(participation)
    Rails.cache.fetch("participation:#{participation.id}:completed_challenges", expires_in: 5.minutes) do
      participation.seasonal_event.event_challenges.joins(:challenge_completions)
                     .where(challenge_completions: { user_id: participation.user_id })
    end
  end

  def self.get_available_challenges(participation)
    Rails.cache.fetch("participation:#{participation.id}:available_challenges", expires_in: 5.minutes) do
      participation.seasonal_event.event_challenges.where(active: true)
    end
  end

  def self.calculate_progress_summary(participation)
    Rails.cache.fetch("participation:#{participation.id}:progress_summary", expires_in: 5.minutes) do
      completed = get_completed_challenges(participation).count
      total = participation.seasonal_event.event_challenges.count
      completion_percentage = calculate_completion_percentage(total, completed)

      {
        points: participation.points,
        rank: participation.rank,
        challenges_completed: completed,
        total_challenges: total,
        completion_percentage: completion_percentage
      }
    end
  end

  private

  def self.calculate_completion_percentage(total, completed)
    return 0 if total.zero?
    ((completed.to_f / total) * 100).round(2)
  end
end