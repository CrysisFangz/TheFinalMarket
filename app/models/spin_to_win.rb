class SpinToWin < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :status, presence: true

  # Associations
  has_many :prizes, class_name: 'SpinToWinPrize'
  has_many :spins, class_name: 'SpinToWinSpin'

  # Enums
  enum status: { inactive: 0, active: 1 }

  # Scopes
  scope :active_wheels, -> { where(status: :active) }

  # Optimized indexes
  index :status
  index :name

  # Delegate to services
  def can_spin?(user)
    spin_service.can_spin?(user)
  end

  def remaining_spins(user)
    spin_service.remaining_spins(user)
  end

  def spin!(user)
    spin_service.spin!(user)
  end

  def user_spin_history(user, limit: 10)
    SpinHistoryPresenter.new(spin_service.user_spin_history(user, limit: limit)).as_json
  end

  def statistics
    SpinStatisticsPresenter.new(statistics_service.statistics).as_json
  end

  def prize_distribution
    statistics_service.prize_distribution
  end

  private

  def spin_service
    @spin_service ||= SpinService.new(self)
  end

  def statistics_service
    @statistics_service ||= SpinStatisticsService.new(self)
  end
end
