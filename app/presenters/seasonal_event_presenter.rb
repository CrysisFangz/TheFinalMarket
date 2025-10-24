class SeasonalEventPresenter
  def initialize(event)
    @event = event
  end

  def statistics
    cache_key = "seasonal_event:#{@event.id}:statistics"
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      {
        total_participants: @event.participants.count,
        total_points_awarded: @event.event_participations.sum(:points),
        average_points: @event.event_participations.average(:points).to_f.round(2),
        top_score: @event.event_participations.maximum(:points),
        challenges_completed: @event.event_challenges.sum(:completion_count),
        event_type: @event.event_type,
        days_remaining: @event.days_remaining
      }
    end
  end

  def leaderboard(limit: 100)
    SeasonalEventLeaderboardService.new(@event).leaderboard(limit: limit)
  end

  def user_rank(user)
    SeasonalEventLeaderboardService.new(@event).user_rank(user)
  end
end