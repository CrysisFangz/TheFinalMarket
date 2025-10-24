class InventoryForecastPresenter
  include CircuitBreaker
  include Retryable

  def initialize(forecast)
    @forecast = forecast
  end

  def as_json(options = {})
    cache_key = "inventory_forecast_presenter:#{@forecast.id}:#{@forecast.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('inventory_forecast_presenter') do
        with_retry do
          {
            id: @forecast.id,
            forecast_date: @forecast.forecast_date,
            forecast_method: @forecast.forecast_method,
            predicted_demand: @forecast.predicted_demand,
            confidence_level: @forecast.confidence_level,
            current_stock: @forecast.current_stock,
            recommended_reorder: @forecast.recommended_reorder,
            stockout_risk: @forecast.stockout_risk,
            created_at: @forecast.created_at,
            updated_at: @forecast.updated_at,
            product: product_data,
            seller: seller_data,
            accuracy_metrics: accuracy_metrics,
            risk_analysis: risk_analysis,
            recommendations: recommendations
          }
        end
      end
    end
  end

  def to_api_response
    as_json.merge(
      metadata: {
        cache_timestamp: Time.current,
        version: '1.0'
      }
    )
  end

  def to_dashboard_response
    as_json.merge(
      dashboard_data: {
        urgency_level: urgency_level,
        action_required: action_required?,
        trend_indicator: trend_indicator,
        efficiency_score: efficiency_score
      }
    )
  end

  private

  def product_data
    Rails.cache.fetch("forecast_product:#{@forecast.product_id}", expires_in: 30.minutes) do
      with_circuit_breaker('product_data') do
        with_retry do
          {
            id: @forecast.product.id,
            name: @forecast.product.name,
            sku: @forecast.product.sku,
            price: @forecast.product.price,
            stock_quantity: @forecast.product.stock_quantity,
            reorder_point: @forecast.product.reorder_point,
            lead_time_days: @forecast.product.lead_time_days
          }
        end
      end
    end
  end

  def seller_data
    Rails.cache.fetch("forecast_seller:#{@forecast.seller_id}", expires_in: 30.minutes) do
      with_circuit_breaker('seller_data') do
        with_retry do
          {
            id: @forecast.seller.id,
            username: @forecast.seller.username,
            business_name: @forecast.seller.business_name,
            total_products: @forecast.seller.products.count
          }
        end
      end
    end
  end

  def accuracy_metrics
    Rails.cache.fetch("forecast_accuracy:#{@forecast.product_id}", expires_in: 20.minutes) do
      with_circuit_breaker('accuracy_metrics') do
        with_retry do
          InventoryPredictionService.get_forecast_accuracy(@forecast.product)
        end
      end
    end
  end

  def risk_analysis
    Rails.cache.fetch("forecast_risk:#{@forecast.id}", expires_in: 15.minutes) do
      with_circuit_breaker('risk_analysis') do
        with_retry do
          stockout_days = @forecast.current_stock / @forecast.predicted_demand.to_f

          {
            stockout_risk_level: @forecast.stockout_risk,
            days_until_stockout: stockout_days.round(1),
            estimated_stockout_date: InventoryCalculationService.estimate_stockout_date(@forecast.product, @forecast),
            risk_score: calculate_risk_score,
            mitigation_strategies: generate_mitigation_strategies
          }
        end
      end
    end
  end

  def recommendations
    Rails.cache.fetch("forecast_recommendations:#{@forecast.id}", expires_in: 15.minutes) do
      with_circuit_breaker('recommendations') do
        with_retry do
          optimal_stock = InventoryCalculationService.calculate_optimal_stock_level(@forecast.product, @forecast)

          {
            reorder_quantity: @forecast.recommended_reorder,
            optimal_stock_level: optimal_stock[:optimal_stock],
            reorder_point: optimal_stock[:reorder_point],
            safety_stock: optimal_stock[:safety_stock],
            urgency: InventoryCalculationService.calculate_urgency(@forecast.product, @forecast),
            action_items: generate_action_items
          }
        end
      end
    end
  end

  def urgency_level
    urgency = InventoryCalculationService.calculate_urgency(@forecast.product, @forecast)

    case urgency
    when 75..100
      'critical'
    when 50..74
      'high'
    when 25..49
      'medium'
    else
      'low'
    end
  end

  def action_required?
    @forecast.stockout_risk.in?(['critical', 'high']) || @forecast.current_stock < @forecast.recommended_reorder
  end

  def trend_indicator
    historical_data = InventoryForecastingService.get_historical_sales(@forecast.product, 30)
    InventoryPredictionService.get_demand_trends(@forecast.product)[:trend_direction]
  end

  def efficiency_score
    accuracy = accuracy_metrics
    return 50 unless accuracy # Default score

    # Calculate efficiency based on accuracy metrics
    mape_score = [100 - (accuracy[:mean_absolute_percentage_error] || 0), 0].max
    bias_score = [100 - (accuracy[:forecast_bias].abs * 10), 0].max

    (mape_score + bias_score) / 2
  end

  def calculate_risk_score
    score = 0

    # Stockout risk contribution
    case @forecast.stockout_risk
    when 'critical'
      score += 50
    when 'high'
      score += 30
    when 'medium'
      score += 15
    end

    # Confidence level contribution
    score += (100 - @forecast.confidence_level) / 2

    # Demand volatility contribution
    historical_data = InventoryForecastingService.get_historical_sales(@forecast.product, 30)
    volatility = InventoryCalculationService.calculate_demand_volatility(historical_data)
    score += [volatility / 2, 25].min

    [score, 100].min
  end

  def generate_mitigation_strategies
    strategies = []

    case @forecast.stockout_risk
    when 'critical'
      strategies << 'Immediate reorder required'
      strategies << 'Consider emergency supplier contact'
      strategies << 'Review lead times'
    when 'high'
      strategies << 'Schedule reorder within 3 days'
      strategies << 'Monitor stock levels closely'
    when 'medium'
      strategies << 'Plan reorder within 7 days'
    end

    if @forecast.confidence_level < 70
      strategies << 'Consider alternative forecasting method'
      strategies << 'Increase safety stock'
    end

    strategies
  end

  def generate_action_items
    actions = []

    if @forecast.current_stock < @forecast.recommended_reorder
      actions << {
        type: 'reorder',
        priority: urgency_level,
        quantity: @forecast.recommended_reorder,
        description: "Reorder #{@forecast.recommended_reorder} units"
      }
    end

    if @forecast.confidence_level < 60
      actions << {
        type: 'review_method',
        priority: 'medium',
        description: 'Review forecasting method accuracy'
      }
    end

    if action_required?
      actions << {
        type: 'monitor',
        priority: 'high',
        description: 'Monitor stock levels daily'
      }
    end

    actions
  end
end