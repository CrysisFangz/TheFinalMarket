class Admin::PredictiveAnalyticsController < Admin::BaseController
  def index
    @predictions = CircuitBreaker.execute_with_fallback(:predictive_analytics) do
      PredictiveAnalyticsService.new.generate_predictions
    end

    respond_to do |format|
      format.html
      format.json { render json: @predictions }
    end
  rescue StandardError => e
    Rails.logger.error "Predictive analytics error: #{e.message}"
    flash[:error] = 'Unable to load predictions.'
    redirect_to admin_predictive_analytics_path
  end

  def sales_forecast
    @forecast = CircuitBreaker.execute_with_fallback(:predictive_analytics_forecast) do
      PredictiveAnalyticsService.new.forecast_sales(
        timeframe: params.fetch(:timeframe, 30).to_i.days
      )
    end

    respond_to do |format|
      format.html
      format.json { render json: @forecast }
      format.csv { send_data SalesForecastPresenter.new(@forecast).to_csv, filename: "sales_forecast.csv" }
    end
  rescue StandardError => e
    Rails.logger.error "Sales forecast error: #{e.message}"
    flash[:error] = 'Unable to generate sales forecast.'
    redirect_to admin_predictive_analytics_path
  end

  def inventory_predictions
    @predictions = CircuitBreaker.execute_with_fallback(:predictive_analytics_inventory) do
      PredictiveAnalyticsService.new.predict_inventory_needs
    end

    respond_to do |format|
      format.html
      format.json { render json: @predictions }
      format.csv { send_data InventoryPredictionsPresenter.new(@predictions).to_csv, filename: "inventory_predictions.csv" }
    end
  rescue StandardError => e
    Rails.logger.error "Inventory predictions error: #{e.message}"
    flash[:error] = 'Unable to generate inventory predictions.'
    redirect_to admin_predictive_analytics_path
  end

  def customer_behavior
    @predictions = CircuitBreaker.execute_with_fallback(:predictive_analytics_behavior) do
      PredictiveAnalyticsService.new.predict_customer_behavior
    end

    respond_to do |format|
      format.html
      format.json { render json: @predictions }
      format.csv { send_data CustomerBehaviorPresenter.new(@predictions).to_csv, filename: "customer_behavior.csv" }
    end
  rescue StandardError => e
    Rails.logger.error "Customer behavior predictions error: #{e.message}"
    flash[:error] = 'Unable to generate customer behavior predictions.'
    redirect_to admin_predictive_analytics_path
  end

  def churn_risk
    @predictions = CircuitBreaker.execute_with_fallback(:predictive_analytics_churn) do
      PredictiveAnalyticsService.new.predict_churn_risk
    end

    respond_to do |format|
      format.html
      format.json { render json: @predictions }
      format.csv { send_data ChurnRiskPresenter.new(@predictions).to_csv, filename: "churn_risk.csv" }
    end
  rescue StandardError => e
    Rails.logger.error "Churn risk predictions error: #{e.message}"
    flash[:error] = 'Unable to generate churn risk predictions.'
    redirect_to admin_predictive_analytics_path
  end

  def retrain_models
    CircuitBreaker.execute_with_fallback(:predictive_analytics_retrain) do
      RetrainModelsJob.perform_later(
        models: params[:models] || ['all'],
        user_id: current_user.id
      )
    end

    redirect_to admin_predictive_analytics_path, notice: 'Models are being retrained. You will be notified when the process is complete.'
  rescue StandardError => e
    Rails.logger.error "Model retraining error: #{e.message}"
    flash[:error] = 'Unable to initiate model retraining.'
    redirect_to admin_predictive_analytics_path
  end

  private
end