class SeasonalEventLifecycleService
  def self.start_event(event)
    event.update!(status: :active, started_at: Time.current)
    NotifyEventStartJob.perform_later(event.id)
  end

  def self.end_event(event)
    event.update!(status: :ended, ended_at: Time.current)
    AwardFinalPrizesJob.perform_later(event.id)
  end

  def self.join_event(event, user)
    return false unless event.active?
    return false if event.participants.include?(user)

    participation = event.event_participations.create!(
      user: user,
      joined_at: Time.current,
      points: 0,
      rank: 0
    )

    participation
  end
end