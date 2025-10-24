class UserReputationEvent < ApplicationRecord
  belongs_to :user, counter_cache: :reputation_score

  # Validations for data integrity
  validates :points, presence: true, numericality: { only_integer: true, allow_nil: false }
  validates :reason, presence: true, length: { maximum: 255 }

  # Scopes for efficient querying
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :positive_points, -> { where('points > 0') }
  scope :negative_points, -> { where('points < 0') }

  # Methods for business logic
  def positive?
    points > 0
  end

  def negative?
    points < 0
  end

  # Ensure immutability for certain fields (override update if needed)
  before_update :prevent_updates_to_critical_fields

  private

  def prevent_updates_to_critical_fields
    # Prevent updates to points and reason after creation to maintain event integrity
    errors.add(:base, 'Cannot update points or reason after creation') if points_changed? || reason_changed?
    throw(:abort) if errors.any?
  end
end
