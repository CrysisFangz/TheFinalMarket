class TreasureHunt < ApplicationRecord
  has_many :treasure_hunt_clues, dependent: :destroy
  has_many :treasure_hunt_participations, dependent: :destroy
  has_many :participants, through: :treasure_hunt_participations, source: :user

  validates :name, presence: true
  validates :status, presence: true
  validates :difficulty, presence: true

  enum status: {
    draft: 0,
    active: 1,
    completed: 2,
    expired: 3
  }

  enum difficulty: {
    easy: 0,
    medium: 1,
    hard: 2,
    expert: 3
  }

  # Scopes
  scope :active_hunts, -> { where(status: :active).where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current) }
  scope :upcoming, -> { where(status: :active).where('starts_at > ?', Time.current) }
  scope :by_difficulty, ->(difficulty) { where(difficulty: difficulty) }

  # Delegate complex operations to services
  def start!
    TreasureHunt::StartService.new(self).call
  end

  def complete!
    TreasureHunt::CompleteService.new(self).call
  end

  def join(user)
    TreasureHunt::JoinService.new(self, user).call
  end

  def can_participate?(user)
    TreasureHunt::JoinService.new(self, user).can_participate?
  end

  def participation_for(user)
    treasure_hunt_participations.find_by(user: user)
  end

  def completed_by?(user)
    participation = participation_for(user)
    participation&.completed?
  end

  def leaderboard(limit: 10)
    service = TreasureHunt::LeaderboardService.new(self, limit: limit)
    presenter = TreasureHunt::LeaderboardPresenter.new(service.call)
    presenter.present
  end

  def statistics
    service = TreasureHunt::StatisticsService.new(self)
    presenter = TreasureHunt::StatisticsPresenter.new(service.call)
    presenter.present
  end

  def calculate_prize(rank)
    TreasureHunt::PrizeCalculator.new(prize_pool).calculate(rank)
  end
end

