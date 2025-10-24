class SeasonalEventLeaderboardService
  def initialize(event)
    @event = event
  end

  def leaderboard(limit: 100)
    cache_key = "seasonal_event:#{@event.id}:leaderboard:#{limit}"
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      participations = @event.event_participations
                             .order(points: :desc, joined_at: :asc)
                             .limit(limit)
                             .includes(:user)
                             .to_a

      participations.each_with_index do |participation, index|
        participation.update_column(:rank, index + 1) unless participation.rank == index + 1
      end

      participations.map.with_index(1) do |participation, index|
        {
          rank: index,
          user: participation.user,
          points: participation.points,
          joined_at: participation.joined_at
        }
      end
    end
  end

  def user_rank(user)
    participation = @event.participation_for(user)
    return nil unless participation

    cache_key = "seasonal_event:#{@event.id}:user_rank:#{user.id}"
    Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      @event.event_participations.where('points > ?', participation.points).count + 1
    end
  end
end