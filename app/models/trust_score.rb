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
  
  # Set trust level before save
  before_save :set_trust_level

  def set_trust_level
    self.trust_level = case score
                       when 90..100 then :highly_trusted
                       when 70..89 then :trusted
                       when 50..69 then :moderate_trust
                       when 30..49 then :low_trust
                       else :untrusted
                       end
  end

  # Delegate to service for current score
  def self.current_for(user)
    TrustScoreService.new(user).current_for_user
  end

  # Delegate to service for calculation
  def self.calculate_for(user)
    TrustScoreService.new(user).calculate_and_create
  end
end

