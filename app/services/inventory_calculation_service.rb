class InventoryCalculationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'inventory_calculation'
  CACHE_TTL = 30.minutes

  def self.calculate_moving_average(data, window = 7)
    cache_key = "#{CACHE_KEY_PREFIX}:moving_avg:#{data.hash}:#{window}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return 0 if data.empty?

          recent_data = data.last(window)
          recent_data.sum / recent_data.count.to_f
        end
      end
    end
  end

  def self.calculate_exponential_smoothing(data, alpha = 0.3)
    cache_key = "#{CACHE_KEY_PREFIX}:exp_smoothing:#{data.hash}:#{alpha}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return 0 if data.empty?

          forecast = data.first.to_f

          data.each do |value|
            forecast = alpha * value + (1 - alpha) * forecast
          end

          forecast
        end
      end
    end
  end

  def self.calculate_linear_regression(data, days_ahead)
    cache_key = "#{CACHE_KEY_PREFIX}:linear_reg:#{data.hash}:#{days_ahead}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
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
      end
    end
  end

  def self.calculate_seasonal_forecast(data, days_ahead)
    cache_key = "#{CACHE_KEY_PREFIX}:seasonal:#{data.hash}:#{days_ahead}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return 0 if data.empty?

          base_forecast = calculate_moving_average(data)

          # Check for weekly seasonality
          day_of_week = (Date.current + days_ahead.days).wday
          seasonal_factor = calculate_seasonal_factor(data, day_of_week)

          base_forecast * seasonal_factor
        end
      end
    end
  end

  def self.calculate_seasonal_factor(data, day_of_week)
    cache_key = "#{CACHE_KEY_PREFIX}:seasonal_factor:#{data.hash}:#{day_of_week}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return 1.0 if data.count < 14

          overall_avg = data.sum / data.count.to_f
          return 1.0 if overall_avg.zero?

          day_values = data.each_slice(7).map { |week| week[day_of_week] || 0 }
          day_avg = day_values.sum / day_values.count.to_f

          day_avg / overall_avg
        end
      end
    end
  end

  def self.calculate_confidence(data)
    cache_key = "#{CACHE_KEY_PREFIX}:confidence:#{data.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return 50 if data.empty?

          # Higher confidence with more data and lower variance
          variance = calculate_variance(data)
          data_points = data.count

          base_confidence = [data_points / 90.0 * 100, 100].min
          variance_penalty = [variance / 10.0, 50].min

          [base_confidence - variance_penalty, 10].max.round(2)
        end
      end
    end
  end

  def self.calculate_variance(data)
    cache_key = "#{CACHE_KEY_PREFIX}:variance:#{data.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return 0 if data.empty?

          mean = data.sum / data.count.to_f
          squared_diffs = data.map { |x| (x - mean) ** 2 }
          squared_diffs.sum / data.count.to_f
        end
      end
    end
  end

  def self.calculate_reorder_quantity(product, predicted_demand)
    cache_key = "#{CACHE_KEY_PREFIX}:reorder_qty:#{product.id}:#{predicted_demand}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          # Economic Order Quantity (EOQ) formula simplified
          daily_demand = predicted_demand
          lead_time_days = product.lead_time_days || 7
          safety_stock = daily_demand * 3 # 3 days safety stock

          reorder_quantity = (daily_demand * lead_time_days) + safety_stock
          reorder_quantity.round
        end
      end
    end
  end

  def self.calculate_stockout_risk(product, predicted_demand)
    cache_key = "#{CACHE_KEY_PREFIX}:stockout_risk:#{product.id}:#{predicted_demand}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return 'none' if product.stock_quantity.zero?

          days_until_stockout = product.stock_quantity / predicted_demand.to_f

          case days_until_stockout
          when 0..3
            'critical'
          when 3..7
            'high'
          when 7..14
            'medium'
          else
            'low'
          end
        end
      end
    end
  end

  def self.calculate_urgency(product, forecast)
    cache_key = "#{CACHE_KEY_PREFIX}:urgency:#{product.id}:#{forecast.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
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
      end
    end
  end

  def self.estimate_stockout_date(product, forecast)
    cache_key = "#{CACHE_KEY_PREFIX}:stockout_date:#{product.id}:#{forecast.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return nil if forecast.predicted_demand.zero?

          days_until_stockout = product.stock_quantity / forecast.predicted_demand.to_f
          Date.current + days_until_stockout.days
        end
      end
    end
  end

  def self.calculate_demand_volatility(data)
    cache_key = "#{CACHE_KEY_PREFIX}:volatility:#{data.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          return 0 if data.count < 7

          # Calculate coefficient of variation
          mean = data.sum / data.count.to_f
          return 0 if mean.zero?

          variance = calculate_variance(data)
          standard_deviation = Math.sqrt(variance)

          (standard_deviation / mean) * 100
        end
      end
    end
  end

  def self.calculate_optimal_stock_level(product, forecast)
    cache_key = "#{CACHE_KEY_PREFIX}:optimal_stock:#{product.id}:#{forecast.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_calculation') do
        with_retry do
          daily_demand = forecast.predicted_demand
          lead_time_days = product.lead_time_days || 7

          # Safety stock based on demand volatility
          historical_data = InventoryForecastingService.get_historical_sales(product, 90)
          volatility = calculate_demand_volatility(historical_data)
          service_level = 0.95 # 95% service level
          z_score = 1.645 # For 95% service level

          safety_stock = z_score * Math.sqrt(lead_time_days) * Math.sqrt(calculate_variance(historical_data))

          reorder_point = (daily_demand * lead_time_days) + safety_stock
          optimal_stock = reorder_point + calculate_reorder_quantity(product, daily_demand)

          {
            reorder_point: reorder_point.round,
            safety_stock: safety_stock.round,
            optimal_stock: optimal_stock.round,
            service_level: service_level
          }
        end
      end
    end
  end

  def self.clear_calculation_cache(product_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:moving_avg:#{product_id}",
      "#{CACHE_KEY_PREFIX}:exp_smoothing:#{product_id}",
      "#{CACHE_KEY_PREFIX}:linear_reg:#{product_id}",
      "#{CACHE_KEY_PREFIX}:seasonal:#{product_id}",
      "#{CACHE_KEY_PREFIX}:confidence:#{product_id}",
      "#{CACHE_KEY_PREFIX}:variance:#{product_id}",
      "#{CACHE_KEY_PREFIX}:reorder_qty:#{product_id}",
      "#{CACHE_KEY_PREFIX}:stockout_risk:#{product_id}",
      "#{CACHE_KEY_PREFIX}:urgency:#{product_id}",
      "#{CACHE_KEY_PREFIX}:stockout_date:#{product_id}",
      "#{CACHE_KEY_PREFIX}:volatility:#{product_id}",
      "#{CACHE_KEY_PREFIX}:optimal_stock:#{product_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end