class TrustScore < ApplicationRecord
  belongs_to :user
  
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :trusted, -> { where('score >= ?', 70) }
  scope :suspicious, -> { where('score < ?', 40) }
  
  # Trust levels
  enum trust_level: {
    untrusted: 0,
    low_trust: 1,
    moderate_trust: 2,
    trusted: 3,
    highly_trusted: 4
  }
  
  # Calculate trust level from score
  before_save :set_trust_level
  
  def set_trust_level
    self.trust_level = if score >= 90
      :highly_trusted
    elsif score >= 70
      :trusted
    elsif score >= 50
      :moderate_trust
    elsif score >= 30
      :low_trust
    else
      :untrusted
    end
  end
  
  # Get current trust score for user
  def self.current_for(user)
    where(user: user).order(created_at: :desc).first
  end
  
  # Calculate trust score for user
  def self.calculate_for(user)
    calculator = TrustScoreCalculator.new(user)
    score_value = calculator.calculate
    
    create!(
      user: user,
      score: score_value,
      factors: calculator.factors,
      calculation_details: calculator.details
    )
  end
  
  # Check if score has improved
  def improved?
    previous = user.trust_scores.where('created_at < ?', created_at).order(created_at: :desc).first
    return false unless previous
    
    score > previous.score
  end
  
  # Check if score has declined
  def declined?
    previous = user.trust_scores.where('created_at < ?', created_at).order(created_at: :desc).first
    return false unless previous
    
    score < previous.score
  end
  
  # Get trust badge
  def badge
    case trust_level.to_sym
    when :highly_trusted
      { name: 'Highly Trusted', color: 'gold', icon: '⭐⭐⭐' }
    when :trusted
      { name: 'Trusted', color: 'green', icon: '⭐⭐' }
    when :moderate_trust
      { name: 'Verified', color: 'blue', icon: '⭐' }
    when :low_trust
      { name: 'New User', color: 'gray', icon: '○' }
    when :untrusted
      { name: 'Unverified', color: 'red', icon: '⚠' }
    end
  end
  
  # Get factors as array
  def factors_array
    factors['factors'] || []
  end
end

