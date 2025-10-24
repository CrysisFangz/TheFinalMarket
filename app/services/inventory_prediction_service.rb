class InventoryPredictionService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'inventory_prediction'
  CACHE_TTL = 15.minutes

  def self.get_reorder_recommendations(seller)
    cache_key = "#{CACHE_KEY_PREFIX}:reorder:#{seller.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_prediction') do
        with_retry do
          products = seller.products.where('stock_quantity < reorder_point')

          recommendations = []

          products.each do |product|
            forecast = InventoryForecastingService.get_latest_forecast(product)

            next unless forecast

            recommendations << {
              product: product,
              current_stock: product.stock_quantity,
              reorder_point: product.reorder_point,
              predicted_demand: forecast.predicted_demand,
              recommended_quantity: forecast.recommended_reorder,
              urgency: InventoryCalculationService.calculate_urgency(product, forecast),
              estimated_stockout_date: InventoryCalculationService.estimate_stockout_date(product, forecast)
            }
          end

          sorted_recommendations = recommendations.sort_by { |r| -r[:urgency] }

          EventPublisher.publish('inventory_prediction.reorder_recommendations_generated', {
            seller_id: seller.id,
            recommendations_count: sorted_recommendations.count,
            urgent_count: sorted_recommendations.count { |r| r[:urgency] > 75 },
            generated_at: Time.current
          })

          sorted_recommendations
        end
      end
    end
  end

  def self.get_overstocked_products(seller)
    cache_key = "#{CACHE_KEY_PREFIX}:overstocked:#{seller.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_prediction') do
        with_retry do
          products = seller.products

          overstocked = []

          products.each do |product|
            next if product.stock_quantity.zero?

            forecast_30_days = InventoryForecast.where(product: product)
                                              .where('forecast_date >= ?', Date.current)
                                              .limit(30)
                                              .sum(:predicted_demand)

            days_of_inventory = product.stock_quantity.to_f / (forecast_30_days / 30.0)

            if days_of_inventory > 90
              overstocked << {
                product: product,
                current_stock: product.stock_quantity,
                days_of_inventory: days_of_inventory.round,
                predicted_30_day_demand: forecast_30_days,
                recommendation: 'Consider promotion or discount'
              }
            end
          end

          sorted_overstocked = overstocked.sort_by { |o| -o[:days_of_inventory] }

          EventPublisher.publish('inventory_prediction.overstocked_products_identified', {
            seller_id: seller.id,
            overstocked_count: sorted_overstocked.count,
            total_excess_inventory: sorted_overstocked.sum { |o| o[:current_stock] },
            generated_at: Time.current
          })

          sorted_overstocked
        end
      end
    end
  end

  def self.get_forecast_accuracy(product, period = 30)
    cache_key = "#{CACHE_KEY_PREFIX}:accuracy:#{product.id}:#{period}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_prediction') do
        with_retry do
          forecasts = InventoryForecast.where(product: product)
                                     .where('forecast_date >= ? AND forecast_date < ?', period.days.ago, Date.current)

          return nil if forecasts.empty?

          errors = forecasts.map do |forecast|
            actual = get_actual_sales(product, forecast.forecast_date)
            (forecast.predicted_demand - actual).abs
          end

          accuracy_metrics = {
            mean_absolute_error: errors.sum / errors.count.to_f,
            mean_absolute_percentage_error: calculate_mape(forecasts),
            forecast_bias: calculate_bias(forecasts)
          }

          EventPublisher.publish('inventory_prediction.accuracy_calculated', {
            product_id: product.id,
            seller_id: product.user_id,
            period: period,
            forecasts_count: forecasts.count,
            mean_absolute_error: accuracy_metrics[:mean_absolute_error],
            mean_absolute_percentage_error: accuracy_metrics[:mean_absolute_percentage_error],
            forecast_bias: accuracy_metrics[:forecast_bias],
            calculated_at: Time.current
          })

          accuracy_metrics
        end
      end
    end
  end

  def self.get_demand_trends(product, days = 90)
    cache_key = "#{CACHE_KEY_PREFIX}:trends:#{product.id}:#{days}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_prediction') do
        with_retry do
          historical_data = InventoryForecastingService.get_historical_sales(product, days)
          forecasts = InventoryForecastingService.get_forecasts_for_product(product)

          trends = {
            historical_average: InventoryCalculationService.calculate_moving_average(historical_data),
            trend_direction: calculate_trend_direction(historical_data),
            seasonal_pattern: detect_seasonal_pattern(historical_data),
            future_demand: forecasts.sum(&:predicted_demand),
            confidence_range: {
              low: forecasts.min_by(&:predicted_demand)&.predicted_demand || 0,
              high: forecasts.max_by(&:predicted_demand)&.predicted_demand || 0
            }
          }

          EventPublisher.publish('inventory_prediction.demand_trends_analyzed', {
            product_id: product.id,
            seller_id: product.user_id,
            days: days,
            trend_direction: trends[:trend_direction],
            seasonal_pattern: trends[:seasonal_pattern],
            future_demand: trends[:future_demand],
            analyzed_at: Time.current
          })

          trends
        end
      end
    end
  end

  def self.get_stockout_alerts(seller)
    cache_key = "#{CACHE_KEY_PREFIX}:stockout_alerts:#{seller.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('inventory_prediction') do
        with_retry do
          alerts = []

          seller.products.each do |product|
            forecast = InventoryForecastingService.get_latest_forecast(product)

            next unless forecast

            stockout_risk = InventoryCalculationService.calculate_stockout_risk(product, forecast.predicted_demand)

            if stockout_risk.in?(['critical', 'high'])
              alerts << {
                product: product,
                current_stock: product.stock_quantity,
                predicted_demand: forecast.predicted_demand,
                stockout_risk: stockout_risk,
                estimated_stockout_date: InventoryCalculationService.estimate_stockout_date(product, forecast),
                urgency: InventoryCalculationService.calculate_urgency(product, forecast)
              }
            end
          end

          sorted_alerts = alerts.sort_by { |a| -a[:urgency] }

          EventPublisher.publish('inventory_prediction.stockout_alerts_generated', {
            seller_id: seller.id,
            alerts_count: sorted_alerts.count,
            critical_alerts: sorted_alerts.count { |a| a[:stockout_risk] == 'critical' },
            high_risk_alerts: sorted_alerts.count { |a| a[:stockout_risk] == 'high' },
            generated_at: Time.current
          })

          sorted_alerts
        end
      end
    end
  end

  private

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

  def self.calculate_trend_direction(data)
    return 'stable' if data.count < 14

    first_half = data.first(data.count / 2)
    second_half = data.last(data.count / 2)

    first_avg = first_half.sum / first_half.count.to_f
    second_avg = second_half.sum / second_half.count.to_f

    if second_avg > first_avg * 1.1
      'increasing'
    elsif second_avg < first_avg * 0.9
      'decreasing'
    else
      'stable'
    end
  end

  def self.detect_seasonal_pattern(data)
    return 'none' if data.count < 28

    # Simple seasonal detection by day of week
    day_averages = (0..6).map do |day|
      day_values = data.each_slice(7).map { |week| week[day] || 0 }
      day_values.sum / day_values.count.to_f
    end

    max_avg = day_averages.max
    min_avg = day_averages.min

    if max_avg > min_avg * 1.2
      'weekly_seasonal'
    else
      'none'
    end
  end

  def self.clear_prediction_cache(seller_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:reorder:#{seller_id}",
      "#{CACHE_KEY_PREFIX}:overstocked:#{seller_id}",
      "#{CACHE_KEY_PREFIX}:stockout_alerts:#{seller_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end