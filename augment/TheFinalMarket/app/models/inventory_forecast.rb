class InventoryForecast < ApplicationRecord
  belongs_to :product
  belongs_to :seller, class_name: 'User'
  
  validates :forecast_date, presence: true
  validates :forecast_method, presence: true
  
  scope :for_date_range, ->(start_date, end_date) { where(forecast_date: start_date..end_date) }
  scope :recent, -> { where('forecast_date >= ?', Date.current) }
  scope :by_method, ->(method) { where(forecast_method: method) }
  
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
    seller = product.seller
    historical_data = get_historical_sales(product, 90)
    
    forecasts = []
    
    (1..days_ahead).each do |day|
      forecast_date = Date.current + day.days
      
      predicted_demand = case method
      when :moving_average
        calculate_moving_average(historical_data)
      when :exponential_smoothing
        calculate_exponential_smoothing(historical_data)
      when :linear_regression
        calculate_linear_regression(historical_data, day)
      when :seasonal_decomposition
        calculate_seasonal_forecast(historical_data, day)
      else
        calculate_moving_average(historical_data)
      end
      
      forecast = create!(
        product: product,
        seller: seller,
        forecast_date: forecast_date,
        forecast_method: method,
        predicted_demand: predicted_demand.round,
        confidence_level: calculate_confidence(historical_data),
        current_stock: product.stock_quantity,
        recommended_reorder: calculate_reorder_quantity(product, predicted_demand),
        stockout_risk: calculate_stockout_risk(product, predicted_demand)
      )
      
      forecasts << forecast
    end
    
    forecasts
  end
  
  # Get reorder recommendations
  def self.reorder_recommendations(seller)
    products = seller.products.where('stock_quantity < reorder_point')
    
    recommendations = []
    
    products.each do |product|
      forecast = where(product: product)
                .where('forecast_date >= ?', Date.current)
                .order(:forecast_date)
                .first
      
      next unless forecast
      
      recommendations << {
        product: product,
        current_stock: product.stock_quantity,
        reorder_point: product.reorder_point,
        predicted_demand: forecast.predicted_demand,
        recommended_quantity: forecast.recommended_reorder,
        urgency: calculate_urgency(product, forecast),
        estimated_stockout_date: estimate_stockout_date(product, forecast)
      }
    end
    
    recommendations.sort_by { |r| -r[:urgency] }
  end
  
  # Get overstocked products
  def self.overstocked_products(seller)
    products = seller.products
    
    overstocked = []
    
    products.each do |product|
      next if product.stock_quantity.zero?
      
      forecast = where(product: product)
                .where('forecast_date >= ?', Date.current)
                .limit(30)
                .sum(:predicted_demand)
      
      days_of_inventory = product.stock_quantity.to_f / (forecast / 30.0)
      
      if days_of_inventory > 90
        overstocked << {
          product: product,
          current_stock: product.stock_quantity,
          days_of_inventory: days_of_inventory.round,
          predicted_30_day_demand: forecast,
          recommendation: 'Consider promotion or discount'
        }
      end
    end
    
    overstocked.sort_by { |o| -o[:days_of_inventory] }
  end
  
  # Accuracy metrics
  def self.forecast_accuracy(product, period = 30)
    forecasts = where(product: product)
               .where('forecast_date >= ? AND forecast_date < ?', period.days.ago, Date.current)
    
    return nil if forecasts.empty?
    
    errors = forecasts.map do |forecast|
      actual = get_actual_sales(product, forecast.forecast_date)
      (forecast.predicted_demand - actual).abs
    end
    
    {
      mean_absolute_error: errors.sum / errors.count.to_f,
      mean_absolute_percentage_error: calculate_mape(forecasts),
      forecast_bias: calculate_bias(forecasts)
    }
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
end

