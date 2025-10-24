class InventoryForecastingService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'inventory_forecasting'
  CACHE_TTL = 20.minutes

  def self.generate_product_forecast(product, days_ahead = 30, method = :moving_average)
    cache_key = "#{CACHE_KEY_PREFIX}:generate:#{product.id}:#{days_ahead}:#{method}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_forecasting') do
        with_retry do
          seller = product.user
          historical_data = get_historical_sales(product, 90)

          forecasts = []

          (1..days_ahead).each do |day|
            forecast_date = Date.current + day.days

            predicted_demand = case method
                               when :moving_average
                                 InventoryCalculationService.calculate_moving_average(historical_data)
                               when :exponential_smoothing
                                 InventoryCalculationService.calculate_exponential_smoothing(historical_data)
                               when :linear_regression
                                 InventoryCalculationService.calculate_linear_regression(historical_data, day)
                               when :seasonal_decomposition
                                 InventoryCalculationService.calculate_seasonal_forecast(historical_data, day)
                               else
                                 InventoryCalculationService.calculate_moving_average(historical_data)
                               end

            forecast = InventoryForecast.create!(
              product: product,
              seller: seller,
              forecast_date: forecast_date,
              forecast_method: method,
              predicted_demand: predicted_demand.round,
              confidence_level: InventoryCalculationService.calculate_confidence(historical_data),
              current_stock: product.stock_quantity,
              recommended_reorder: InventoryCalculationService.calculate_reorder_quantity(product, predicted_demand),
              stockout_risk: InventoryCalculationService.calculate_stockout_risk(product, predicted_demand)
            )

            forecasts << forecast
          end

          EventPublisher.publish('inventory_forecast.generated', {
            product_id: product.id,
            seller_id: seller.id,
            days_ahead: days_ahead,
            method: method,
            forecasts_count: forecasts.count,
            average_confidence: forecasts.sum(&:confidence_level) / forecasts.count,
            generated_at: Time.current
          })

          forecasts
        end
      end
    end
  end

  def self.get_historical_sales(product, days)
    cache_key = "#{CACHE_KEY_PREFIX}:historical:#{product.id}:#{days}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_forecasting') do
        with_retry do
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
      end
    end
  end

  def self.get_forecasts_for_product(product, start_date = Date.current, end_date = 30.days.from_now)
    cache_key = "#{CACHE_KEY_PREFIX}:forecasts:#{product.id}:#{start_date.to_s}:#{end_date.to_s}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_forecasting') do
        with_retry do
          InventoryForecast.where(product: product)
                          .where(forecast_date: start_date..end_date)
                          .order(:forecast_date)
                          .to_a
        end
      end
    end
  end

  def self.get_latest_forecast(product)
    cache_key = "#{CACHE_KEY_PREFIX}:latest:#{product.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_forecasting') do
        with_retry do
          InventoryForecast.where(product: product)
                          .where('forecast_date >= ?', Date.current)
                          .order(:forecast_date)
                          .first
        end
      end
    end
  end

  def self.clear_forecasting_cache(product_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:generate:#{product_id}",
      "#{CACHE_KEY_PREFIX}:historical:#{product_id}",
      "#{CACHE_KEY_PREFIX}:forecasts:#{product_id}",
      "#{CACHE_KEY_PREFIX}:latest:#{product_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end