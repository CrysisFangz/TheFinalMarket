class SeasonalEventParticipationService
  def initialize(event)
    @event = event
  end

  def award_points(user, points, reason = nil)
    participation = @event.participation_for(user)
    return unless participation

    participation.increment!(:points, points)
    UpdateLeaderboardJob.perform_later(@event.id)

    check_milestone_rewards(user, participation.points)
  end

  private

  def check_milestone_rewards(user, points)
    @event.event_rewards.where(reward_type: :milestone)
         .where('threshold <= ?', points)
         .where.not(id: user.claimed_event_rewards.select(:event_reward_id))
         .each do |reward|
      reward.award_to(user)
    end
  end
end