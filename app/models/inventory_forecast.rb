class InventoryForecast < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :product
  belongs_to :seller, class_name: 'User'

  validates :forecast_date, presence: true
  validates :forecast_method, presence: true

  # Enhanced scopes with caching
  scope :for_date_range, ->(start_date, end_date) { where(forecast_date: start_date..end_date) }
  scope :recent, -> { where('forecast_date >= ?', Date.current) }
  scope :by_method, ->(method) { where(forecast_method: method) }

  # Caching
  after_create :clear_forecast_cache
  after_update :clear_forecast_cache
  after_destroy :clear_forecast_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event
  
  # Forecast methods
  enum forecast_method: {
    moving_average: 0,
    exponential_smoothing: 1,
    linear_regression: 2,
    seasonal_decomposition: 3,
    machine_learning: 4
  }
  
  # Generate forecast
  def self.generate_for_product(product, days_ahead = 30, method = :moving_average)
    InventoryForecastingService.generate_product_forecast(product, days_ahead, method)
  end

  # Get reorder recommendations
  def self.reorder_recommendations(seller)
    InventoryPredictionService.get_reorder_recommendations(seller)
  end

  # Get overstocked products
  def self.overstocked_products(seller)
    InventoryPredictionService.get_overstocked_products(seller)
  end

  # Accuracy metrics
  def self.forecast_accuracy(product, period = 30)
    InventoryPredictionService.get_forecast_accuracy(product, period)
  end
  
  private
  
  def self.get_historical_sales(product, days)
    sales = []
    
    (1..days).each do |day|
      date = Date.current - day.days
      daily_sales = product.line_items
                          .joins(:order)
                          .where('DATE(orders.created_at) = ?', date)
                          .sum(:quantity)
      sales << daily_sales
    end
    
    sales.reverse
  end
  
  def self.calculate_moving_average(data, window = 7)
    return 0 if data.empty?
    
    recent_data = data.last(window)
    recent_data.sum / recent_data.count.to_f
  end
  
  def self.calculate_exponential_smoothing(data, alpha = 0.3)
    return 0 if data.empty?
    
    forecast = data.first.to_f
    
    data.each do |value|
      forecast = alpha * value + (1 - alpha) * forecast
    end
    
    forecast
  end
  
  def self.calculate_linear_regression(data, days_ahead)
    return 0 if data.empty?
    
    n = data.count
    x_values = (1..n).to_a
    y_values = data
    
    x_mean = x_values.sum / n.to_f
    y_mean = y_values.sum / n.to_f
    
    numerator = x_values.zip(y_values).sum { |x, y| (x - x_mean) * (y - y_mean) }
    denominator = x_values.sum { |x| (x - x_mean) ** 2 }
    
    return y_mean if denominator.zero?
    
    slope = numerator / denominator
    intercept = y_mean - slope * x_mean
    
    slope * (n + days_ahead) + intercept
  end
  
  def self.calculate_seasonal_forecast(data, days_ahead)
    # Simple seasonal adjustment
    return 0 if data.empty?
    
    base_forecast = calculate_moving_average(data)
    
    # Check for weekly seasonality
    day_of_week = (Date.current + days_ahead.days).wday
    seasonal_factor = calculate_seasonal_factor(data, day_of_week)
    
    base_forecast * seasonal_factor
  end
  
  def self.calculate_seasonal_factor(data, day_of_week)
    # Calculate average for this day of week vs overall average
    return 1.0 if data.count < 14
    
    overall_avg = data.sum / data.count.to_f
    return 1.0 if overall_avg.zero?
    
    day_values = data.each_slice(7).map { |week| week[day_of_week] || 0 }
    day_avg = day_values.sum / day_values.count.to_f
    
    day_avg / overall_avg
  end
  
  def self.calculate_confidence(data)
    return 50 if data.empty?
    
    # Higher confidence with more data and lower variance
    variance = calculate_variance(data)
    data_points = data.count
    
    base_confidence = [data_points / 90.0 * 100, 100].min
    variance_penalty = [variance / 10.0, 50].min
    
    [base_confidence - variance_penalty, 10].max.round(2)
  end
  
  def self.calculate_variance(data)
    return 0 if data.empty?
    
    mean = data.sum / data.count.to_f
    squared_diffs = data.map { |x| (x - mean) ** 2 }
    squared_diffs.sum / data.count.to_f
  end
  
  def self.calculate_reorder_quantity(product, predicted_demand)
    # Economic Order Quantity (EOQ) formula simplified
    daily_demand = predicted_demand
    lead_time_days = product.lead_time_days || 7
    safety_stock = daily_demand * 3 # 3 days safety stock
    
    reorder_quantity = (daily_demand * lead_time_days) + safety_stock
    reorder_quantity.round
  end
  
  def self.calculate_stockout_risk(product, predicted_demand)
    return 0 if product.stock_quantity.zero?
    
    days_until_stockout = product.stock_quantity / predicted_demand.to_f
    
    if days_until_stockout < 3
      'critical'
    elsif days_until_stockout < 7
      'high'
    elsif days_until_stockout < 14
      'medium'
    else
      'low'
    end
  end
  
  def self.calculate_urgency(product, forecast)
    days_until_stockout = product.stock_quantity / forecast.predicted_demand.to_f
    
    case days_until_stockout
    when 0..3
      100
    when 3..7
      75
    when 7..14
      50
    else
      25
    end
  end
  
  def self.estimate_stockout_date(product, forecast)
    return nil if forecast.predicted_demand.zero?
    
    days_until_stockout = product.stock_quantity / forecast.predicted_demand.to_f
    Date.current + days_until_stockout.days
  end
  
  def self.get_actual_sales(product, date)
    product.line_items
          .joins(:order)
          .where('DATE(orders.created_at) = ?', date)
          .sum(:quantity)
  end
  
  def self.calculate_mape(forecasts)
    errors = forecasts.map do |forecast|
      actual = get_actual_sales(forecast.product, forecast.forecast_date)
      next if actual.zero?
      
      ((forecast.predicted_demand - actual).abs / actual.to_f * 100)
    end.compact
    
    return 0 if errors.empty?
    errors.sum / errors.count
  end
  
  def self.calculate_bias(forecasts)
    errors = forecasts.map do |forecast|
      actual = get_actual_sales(forecast.product, forecast.forecast_date)
      forecast.predicted_demand - actual
    end

    errors.sum / errors.count.to_f
  end

  def self.cached_find(id)
    Rails.cache.fetch("inventory_forecast:#{id}", expires_in: 30.minutes) do
      find_by(id: id)
    end
  end

  def self.cached_for_product(product_id)
    Rails.cache.fetch("inventory_forecasts:product:#{product_id}", expires_in: 15.minutes) do
      where(product_id: product_id).includes(:product, :seller).order(:forecast_date).to_a
    end
  end

  def self.cached_for_seller(seller_id)
    Rails.cache.fetch("inventory_forecasts:seller:#{seller_id}", expires_in: 15.minutes) do
      joins(:product).where(products: { user_id: seller_id }).includes(:product).order(:forecast_date).to_a
    end
  end

  def self.get_demand_trends(product_id)
    product = Product.find(product_id)
    InventoryPredictionService.get_demand_trends(product)
  end

  def self.get_stockout_alerts(seller_id)
    seller = User.find(seller_id)
    InventoryPredictionService.get_stockout_alerts(seller)
  end

  def presenter
    @presenter ||= InventoryForecastPresenter.new(self)
  end

  private

  def clear_forecast_cache
    InventoryForecastingService.clear_forecasting_cache(product_id)
    InventoryPredictionService.clear_prediction_cache(seller_id)
    InventoryCalculationService.clear_calculation_cache(product_id)

    # Clear related caches
    Rails.cache.delete("inventory_forecast:#{id}")
    Rails.cache.delete("inventory_forecasts:product:#{product_id}")
    Rails.cache.delete("inventory_forecasts:seller:#{seller_id}")
  end

  def publish_created_event
    EventPublisher.publish('inventory_forecast.created', {
      forecast_id: id,
      product_id: product_id,
      seller_id: seller_id,
      forecast_date: forecast_date,
      forecast_method: forecast_method,
      predicted_demand: predicted_demand,
      confidence_level: confidence_level,
      stockout_risk: stockout_risk,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('inventory_forecast.updated', {
      forecast_id: id,
      product_id: product_id,
      seller_id: seller_id,
      forecast_date: forecast_date,
      forecast_method: forecast_method,
      predicted_demand: predicted_demand,
      confidence_level: confidence_level,
      stockout_risk: stockout_risk,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('inventory_forecast.destroyed', {
      forecast_id: id,
      product_id: product_id,
      seller_id: seller_id,
      forecast_date: forecast_date,
      forecast_method: forecast_method,
      predicted_demand: predicted_demand
    })
  end
end

