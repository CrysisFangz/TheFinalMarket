class SocialCompetition < ApplicationRecord
  has_many :competition_participants, dependent: :destroy
  has_many :participants, through: :competition_participants, source: :user
  has_many :competition_teams, dependent: :destroy

  validates :name, presence: true
  validates :competition_type, presence: true
  validates :status, presence: true

  enum competition_type: {
    individual: 0,
    team: 1,
    guild: 2,
    bracket: 3
  }

  enum status: {
    registration: 0,
    active: 1,
    finished: 2,
    cancelled: 3
  }

  enum scoring_type: {
    points: 0,
    purchases: 1,
    sales: 2,
    reviews: 3,
    referrals: 4,
    engagement: 5
  }

  # Scopes
  scope :active_competitions, -> { where(status: :active) }
  scope :open_for_registration, -> { where(status: :registration).where('registration_ends_at > ?', Time.current) }

  # Delegate to services
  def register(user, team_id: nil)
    circuit_breaker.execute do
      registration_service.register_user(id, user.id, team_id)
    end
  end

  def can_register?(user)
    registration? &&
    registration_ends_at > Time.current &&
    !participants.include?(user) &&
    (max_participants.nil? || participants.count < max_participants)
  end

  def start!
    circuit_breaker.execute do
      update!(status: :active, started_at: Time.current)
      event_publisher.publish(Domain::SocialCompetitions::Events::CompetitionStartedEvent.new(id, Time.current))
      notification_service.notify_participants(id, 'Competition has started!')
    end
  end

  def finish!
    circuit_breaker.execute do
      update!(status: :finished, ended_at: Time.current)
      leaderboard_service.calculate_final_rankings(id)
      prize_service.award_prizes(id)
      event_publisher.publish(Domain::SocialCompetitions::Events::CompetitionFinishedEvent.new(id, Time.current))
    end
  end

  def update_score(user, points)
    circuit_breaker.execute do
      scoring_service.update_score(id, user.id, points)
    end
  end

  def leaderboard(limit: 100)
    circuit_breaker.execute do
      leaderboard_service.leaderboard(id, limit)
    end
  end

  def user_rank(user)
    circuit_breaker.execute do
      participant = competition_participants.find_by(user: user)
      participant&.rank
    end
  end

  def statistics
    circuit_breaker.execute do
      {
        total_participants: participants.count,
        total_teams: competition_teams.count,
        total_score: competition_participants.sum(:score),
        average_score: competition_participants.average(:score).to_f.round(2),
        top_score: competition_participants.maximum(:score),
        competition_type: competition_type,
        status: status,
        days_remaining: days_remaining
      }
    end
  end

  private

  def circuit_breaker
    @circuit_breaker ||= CircuitBreakers::CompetitionCircuitBreaker.new
  end

  def registration_service
    @registration_service ||= Domain::SocialCompetitions::Services::CompetitionRegistrationService.new(
      Domain::SocialCompetitions::Repositories::CompetitionRepository.new,
      Domain::SocialCompetitions::Repositories::CompetitionParticipantRepository.new
    )
  end

  def scoring_service
    @scoring_service ||= Domain::SocialCompetitions::Services::CompetitionScoringService.new(
      Domain::SocialCompetitions::Repositories::CompetitionParticipantRepository.new,
      ::CompetitionTeam
    )
  end

  def leaderboard_service
    @leaderboard_service ||= Domain::SocialCompetitions::Services::CompetitionLeaderboardService.new(
      Domain::SocialCompetitions::Repositories::CompetitionParticipantRepository.new,
      ::CompetitionTeam,
      Domain::SocialCompetitions::Presenters::LeaderboardPresenter
    )
  end

  def prize_service
    @prize_service ||= Domain::SocialCompetitions::Services::CompetitionPrizeService.new(
      ::User,
      ::Notification,
      ::SocialCompetition
    )
  end

  def notification_service
    @notification_service ||= Domain::SocialCompetitions::Services::CompetitionNotificationService.new(
      ::Notification,
      self
    )
  end

  def event_publisher
    @event_publisher ||= Domain::SocialCompetitions::Infrastructure::EventPublisher.new
  end

  def days_remaining
    return 0 unless active?
    return 0 if ends_at < Time.current
    ((ends_at - Time.current) / 1.day).ceil
  end
end

