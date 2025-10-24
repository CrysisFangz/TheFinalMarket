class PredictiveModel < ApplicationRecord
  has_many :predictions, dependent: :destroy
  
  validates :model_name, presence: true, uniqueness: true
  validates :model_type, presence: true
  
  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(model_type: type) }
  
  # Model types
  MODEL_TYPES = %w[
    ltv_prediction
    churn_prediction
    demand_forecast
    revenue_forecast
    price_optimization
    recommendation
  ].freeze
  
  validates :model_type, inclusion: { in: MODEL_TYPES }
  
  # Make a prediction
  def predict(input_data)
    execution_service.predict(input_data)
  end

  # Train the model
  def train!
    training_service.train!
  end

  # Additional methods that delegate to services
  def batch_predict(input_data_array)
    execution_service.batch_predict(input_data_array)
  end

  def validate_prediction_input(input_data)
    execution_service.validate_prediction_input(input_data)
  end

  def retrain!(new_data = nil)
    training_service.retrain!(new_data)
  end

  def evaluate_performance(test_data)
    training_service.evaluate_performance(test_data)
  end

  def optimize_hyperparameters
    training_service.optimize_hyperparameters
  end

  def model_performance
    {
      accuracy: accuracy,
      prediction_count: prediction_count,
      last_trained: trained_at,
      last_evaluation: last_evaluation_at,
      evaluation_accuracy: evaluation_accuracy
    }
  end

  def training_history
    training_events.order(occurred_at: :desc).limit(10)
  end

  def prediction_accuracy
    return nil if predictions.where.not(actual_outcome: nil).count < 5

    correct_predictions = predictions.where.not(actual_outcome: nil).count do |prediction|
      prediction.accuracy.present? && prediction.accuracy > 0.7
    end

    total_predictions = predictions.where.not(actual_outcome: nil).count
    (correct_predictions.to_f / total_predictions * 100).round(2)
  end

  private

  def execution_service
    @execution_service ||= PredictiveModelExecutionService.new(self)
  end

  def training_service
    @training_service ||= PredictiveModelTrainingService.new(self)
  end
end

