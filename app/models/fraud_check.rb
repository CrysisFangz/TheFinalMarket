class FraudCheck < ApplicationRecord
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
  
  # Calculate risk level from score
  before_save :set_risk_level
  
  def set_risk_level
    self.risk_level = if risk_score >= 80
      :critical
    elsif risk_score >= 70
      :high
    elsif risk_score >= 40
      :medium
    else
      :low
    end
  end
  
  # Check if this is a high-risk check
  def high_risk?
    risk_score >= 70
  end
  
  # Check if action is required
  def requires_action?
    high_risk? && action_taken == 'none'
  end
  
  # Get human-readable risk description
  def risk_description
    case risk_level.to_sym
    when :critical
      "Critical Risk - Immediate action required"
    when :high
      "High Risk - Review recommended"
    when :medium
      "Medium Risk - Monitor closely"
    when :low
      "Low Risk - Normal activity"
    end
  end
  
  # Get risk factors as array
  def risk_factors_array
    factors['factors'] || []
  end
  
  # Add a risk factor
  def add_risk_factor(factor, weight)
    self.factors ||= { 'factors' => [] }
    self.factors['factors'] << { 'factor' => factor, 'weight' => weight }
  end
end

