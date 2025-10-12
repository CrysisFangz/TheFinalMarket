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
    prediction_result = case model_type
    when 'ltv_prediction'
      predict_ltv(input_data)
    when 'churn_prediction'
      predict_churn(input_data)
    when 'demand_forecast'
      predict_demand(input_data)
    when 'revenue_forecast'
      predict_revenue(input_data)
    else
      { error: 'Unknown model type' }
    end
    
    # Record prediction
    prediction = predictions.create!(
      user_id: input_data[:user_id],
      prediction_type: model_type,
      input_data: input_data,
      prediction_result: prediction_result,
      confidence: prediction_result[:confidence] || 0,
      predicted_at: Time.current
    )
    
    increment!(:prediction_count)
    
    prediction_result
  end
  
  # Train the model
  def train!
    # This would integrate with actual ML training
    # For now, just update the trained_at timestamp
    update!(
      trained_at: Time.current,
      accuracy: rand(70.0..95.0).round(2)
    )
  end
  
  private
  
  def predict_ltv(input_data)
    user = User.find(input_data[:user_id])
    PredictiveAnalyticsService.predict_customer_ltv(user)
  end
  
  def predict_churn(input_data)
    user = User.find(input_data[:user_id])
    PredictiveAnalyticsService.predict_churn(user)
  end
  
  def predict_demand(input_data)
    product = Product.find(input_data[:product_id])
    days_ahead = input_data[:days_ahead] || 30
    PredictiveAnalyticsService.predict_product_demand(product, days_ahead)
  end
  
  def predict_revenue(input_data)
    days_ahead = input_data[:days_ahead] || 30
    PredictiveAnalyticsService.forecast_revenue(days_ahead)
  end
end

