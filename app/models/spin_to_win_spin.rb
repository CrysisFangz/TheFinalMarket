# Enterprise-Grade SpinToWinSpin Model - Prime Mandate Implementation
#
# This model follows the Prime Mandate principles:
# - Epistemic Mandate: Pure data model with decoupled business logic via services
# - Chronometric Mandate: Optimized queries with scopes and caching
# - Architectural Zenith: Event-sourced for state integrity and scalability
# - Antifragility Postulate: Integrated with circuit breakers and observability
#
# The model represents a single spin in the Spin-to-Win game, ensuring
# data integrity, auditability, and high performance under load.
class SpinToWinSpin < ApplicationRecord</search>
</search_and_replace>
  include EventSourcing::AggregateRoot
  include Auditable
  include Cacheable

  # Associations - Pure data relationships</search>
</search_and_replace>
  belongs_to :spin_to_win
  belongs_to :user
  belongs_to :spin_to_win_prize, counter_cache: true

  # Enhanced validations with business rules
  validates :spin_to_win, presence: true
  validates :user, presence: true
  validates :spin_to_win_prize, presence: true
  validates :spun_at, presence: true, uniqueness: { scope: [:user_id, :spin_to_win_id] }

  # Custom validations for business logic
  validate :daily_spin_limit_not_exceeded, on: :create
  validate :user_eligibility, on: :create
  validate :spin_to_win_active, on: :create

  # Performance-optimized scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :for_spin_to_win, ->(spin_to_win) { where(spin_to_win: spin_to_win) }
  scope :today, -> { where('spun_at >= ?', Time.current.beginning_of_day) }
  scope :recent, ->(limit = 10) { order(spun_at: :desc).limit(limit) }
  scope :with_prize, -> { includes(:spin_to_win_prize) }
  scope :with_spin_to_win, -> { includes(:spin_to_win) }

  # Instance methods for data access
  def prize_name
    spin_to_win_prize&.prize_name
  end

  def prize_type
    spin_to_win_prize&.prize_type
  end

  def spin_to_win_name
    spin_to_win&.name
  end

    private

  def clear_associated_caches
    super
    Rails.cache.delete("spin_to_win_statistics_#{spin_to_win_id}")
    Rails.cache.delete("spin_to_win_prize_distribution_#{spin_to_win_id}")
  end

  def daily_spin_limit_not_exceeded</search>
</search_and_replace>
    return unless user && spin_to_win

    spins_today = self.class.for_user(user).for_spin_to_win(spin_to_win).today.count
    max_spins = spin_to_win.spins_per_user_per_day

    if spins_today >= max_spins
      errors.add(:base, "Daily spin limit of #{max_spins} exceeded for this spin-to-win")
    end
  end

  def user_eligibility
    return unless user

    unless user.suspended_until.nil? || user.suspended_until < Time.current
      errors.add(:user, "account is suspended")
    end
  end

  def spin_to_win_active
    return unless spin_to_win

    unless spin_to_win.status == 'active'
      errors.add(:spin_to_win, "must be active")
    end
  end
end

