class FraudCheck < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :checkable, polymorphic: true
  belongs_to :user, optional: true

  validates :check_type, presence: true
  validates :risk_score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :recent, -> { where('created_at > ?', 30.days.ago) }
  scope :high_risk, -> { where('risk_score >= ?', 70) }
  scope :medium_risk, -> { where('risk_score >= ? AND risk_score < ?', 40, 70) }
  scope :low_risk, -> { where('risk_score < ?', 40) }
  scope :flagged, -> { where(flagged: true) }
  scope :for_user, ->(user) { where(user: user) }

  # Check types
  enum check_type: {
    account_creation: 0,
    login_attempt: 1,
    order_placement: 2,
    payment_method: 3,
    profile_update: 4,
    listing_creation: 5,
    message_sent: 6,
    review_posted: 7,
    withdrawal_request: 8,
    password_reset: 9
  }

  # Risk levels
  enum risk_level: {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }

  # Actions taken
  enum action_taken: {
    none: 0,
    flagged_for_review: 1,
    blocked: 2,
    requires_verification: 3,
    account_suspended: 4,
    transaction_cancelled: 5
  }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Calculate risk level from score
  before_save :set_risk_level

  def set_risk_level
    RiskAssessmentService.set_risk_level(self)
  end

  # Check if this is a high-risk check
  def high_risk?
    RiskAssessmentService.high_risk?(self)
  end

  # Check if action is required
  def requires_action?
    RiskAssessmentService.requires_action?(self)
  end

  # Get human-readable risk description
  def risk_description
    RiskAssessmentService.get_risk_description(self)
  end

  # Get risk factors as array
  def risk_factors_array
    RiskFactorsService.get_risk_factors_array(self)
  end

  # Add a risk factor
  def add_risk_factor(factor, weight)
    RiskFactorsService.add_risk_factor(self, factor, weight)
  end

  private

  def publish_created_event
    EventPublisher.publish('fraud_check.created', {
      check_id: id,
      checkable_type: checkable_type,
      checkable_id: checkable_id,
      user_id: user_id,
      check_type: check_type,
      risk_score: risk_score,
      risk_level: risk_level,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('fraud_check.updated', {
      check_id: id,
      checkable_type: checkable_type,
      checkable_id: checkable_id,
      user_id: user_id,
      check_type: check_type,
      risk_score: risk_score,
      risk_level: risk_level,
      action_taken: action_taken,
      flagged: flagged?,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('fraud_check.destroyed', {
      check_id: id,
      checkable_type: checkable_type,
      checkable_id: checkable_id,
      user_id: user_id,
      check_type: check_type,
      risk_score: risk_score
    })
  end
end