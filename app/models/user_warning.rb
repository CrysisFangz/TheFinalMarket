class UserWarning < ApplicationRecord
  belongs_to :user
  belongs_to :moderator, class_name: 'User'

  enum level: { minor: 0, moderate: 1, severe: 2 }

  validates :reason, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :level, presence: true
  validates :user_id, presence: true
  validates :moderator_id, presence: true
  validate :moderator_has_permission
  validate :user_not_already_suspended

  # Optimized scopes with eager loading to prevent N+1 queries
  scope :active, -> { where('expires_at > ? OR expires_at IS NULL', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :with_user_and_moderator, -> { includes(:user, :moderator) }
  scope :by_level, ->(level) { where(level: level) }
  scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }

  def active?
    expires_at.nil? || expires_at > Time.current
  end

  # Public method to issue a warning using the service
  def self.issue_warning(user_id, moderator_id, reason, level, expires_at = nil)
    WarningService.issue_warning(user_id, moderator_id, reason, level, expires_at)
  end

  # Public method to check for suspension
  def self.check_suspension(user_id, moderator_id)
    WarningService.check_and_apply_suspension(user_id, moderator_id)
  end

  private

  def moderator_has_permission
    return if moderator.blank?

    unless moderator.moderator? || moderator.admin?
      errors.add(:moderator, "must be a moderator or admin")
    end
  end

  def user_not_already_suspended
    return if user.blank?

    if user.suspended_until.present? && user.suspended_until > Time.current
      errors.add(:user, "is already suspended")
    end
  end
end
