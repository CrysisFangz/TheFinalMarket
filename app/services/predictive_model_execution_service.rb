class PredictiveModelExecutionService
  attr_reader :model

  def initialize(model)
    @model = model
  end

  def predict(input_data)
    Rails.logger.info("Executing prediction for model: #{model.model_name}, type: #{model.model_type}, user: #{input_data[:user_id]}")

    begin
      prediction_result = execute_prediction(input_data)

      # Record prediction
      prediction = record_prediction(input_data, prediction_result)

      # Update model statistics
      model.increment!(:prediction_count)

      Rails.logger.info("Successfully executed prediction for model: #{model.model_name}, prediction ID: #{prediction.id}")
      prediction_result
    rescue => e
      Rails.logger.error("Failed to execute prediction for model: #{model.model_name}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      { error: e.message }
    end
  end

  def batch_predict(input_data_array)
    Rails.logger.info("Executing batch prediction for model: #{model.model_name}, count: #{input_data_array.count}")

    begin
      results = []
      prediction_records = []

      input_data_array.each do |input_data|
        prediction_result = execute_prediction(input_data)
        prediction_record = record_prediction(input_data, prediction_result)

        results << prediction_result
        prediction_records << prediction_record
      end

      # Update model statistics
      model.increment!(:prediction_count, input_data_array.count)

      Rails.logger.info("Successfully executed batch prediction for model: #{model.model_name}, count: #{results.count}")
      results
    rescue => e
      Rails.logger.error("Failed to execute batch prediction for model: #{model.model_name}. Error: #{e.message}")
      input_data_array.map { { error: e.message } }
    end
  end

  def validate_prediction_input(input_data)
    Rails.logger.debug("Validating prediction input for model: #{model.model_name}")

    begin
      case model.model_type
      when 'ltv_prediction', 'churn_prediction'
        validate_user_input(input_data)
      when 'demand_forecast'
        validate_product_input(input_data)
      when 'revenue_forecast'
        validate_revenue_input(input_data)
      else
        { valid: false, error: "Unknown model type: #{model.model_type}" }
      end
    rescue => e
      Rails.logger.error("Failed to validate prediction input for model: #{model.model_name}. Error: #{e.message}")
      { valid: false, error: e.message }
    end
  end

  private

  def execute_prediction(input_data)
    Rails.logger.debug("Executing prediction logic for model: #{model.model_name}")

    begin
      case model.model_type
      when 'ltv_prediction'
        execute_ltv_prediction(input_data)
      when 'churn_prediction'
        execute_churn_prediction(input_data)
      when 'demand_forecast'
        execute_demand_prediction(input_data)
      when 'revenue_forecast'
        execute_revenue_prediction(input_data)
      else
        { error: 'Unknown model type' }
      end
    rescue => e
      Rails.logger.error("Failed to execute prediction logic for model: #{model.model_name}. Error: #{e.message}")
      { error: e.message }
    end
  end

  def execute_ltv_prediction(input_data)
    user = User.find(input_data[:user_id])
    PredictiveAnalyticsService.predict_customer_ltv(user)
  end

  def execute_churn_prediction(input_data)
    user = User.find(input_data[:user_id])
    PredictiveAnalyticsService.predict_churn(user)
  end

  def execute_demand_prediction(input_data)
    product = Product.find(input_data[:product_id])
    days_ahead = input_data[:days_ahead] || 30
    PredictiveAnalyticsService.predict_product_demand(product, days_ahead)
  end

  def execute_revenue_prediction(input_data)
    days_ahead = input_data[:days_ahead] || 30
    PredictiveAnalyticsService.forecast_revenue(days_ahead)
  end

  def record_prediction(input_data, prediction_result)
    Rails.logger.debug("Recording prediction for model: #{model.model_name}")

    begin
      prediction = model.predictions.create!(
        user_id: input_data[:user_id],
        prediction_type: model.model_type,
        input_data: input_data,
        prediction_result: prediction_result,
        confidence: prediction_result[:confidence] || 0,
        predicted_at: Time.current
      )

      Rails.logger.debug("Successfully recorded prediction ID: #{prediction.id}")
      prediction
    rescue => e
      Rails.logger.error("Failed to record prediction for model: #{model.model_name}. Error: #{e.message}")
      raise e
    end
  end

  def validate_user_input(input_data)
    if input_data[:user_id].blank?
      { valid: false, error: 'user_id is required' }
    elsif User.find_by(id: input_data[:user_id]).blank?
      { valid: false, error: 'Invalid user_id' }
    else
      { valid: true }
    end
  end

  def validate_product_input(input_data)
    if input_data[:product_id].blank?
      { valid: false, error: 'product_id is required' }
    elsif Product.find_by(id: input_data[:product_id]).blank?
      { valid: false, error: 'Invalid product_id' }
    else
      { valid: true }
    end
  end

  def validate_revenue_input(input_data)
    if input_data[:days_ahead].present? && !input_data[:days_ahead].is_a?(Integer)
      { valid: false, error: 'days_ahead must be an integer' }
    else
      { valid: true }
    end
  end
end