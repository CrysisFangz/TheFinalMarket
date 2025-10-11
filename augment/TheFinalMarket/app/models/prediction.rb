class Prediction < ApplicationRecord
  belongs_to :predictive_model
  belongs_to :user, optional: true
  
  validates :prediction_type, presence: true
  validates :predicted_at, presence: true
  
  scope :recent, -> { where('predicted_at > ?', 30.days.ago) }
  scope :by_type, ->(type) { where(prediction_type: type) }
  scope :high_confidence, -> { where('confidence >= ?', 80) }
  
  # Get prediction accuracy (if actual outcome is known)
  def accuracy
    return nil unless actual_outcome.present?
    
    # This would compare predicted vs actual
    # Implementation depends on prediction type
    0
  end
end

