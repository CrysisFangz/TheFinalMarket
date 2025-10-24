class OmnichannelCustomerAnalyticsService
  attr_reader :customer

  def initialize(customer)
    @customer = customer
  end

  def channel_metrics(channel)
    Rails.logger.debug("Generating channel metrics for customer ID: #{customer.id}, channel: #{channel.name}")

    begin
      interactions = customer.channel_interactions.where(sales_channel: channel)
      orders = Order.where(user: customer.user, sales_channel: channel)

      metrics = {
        interaction_count: interactions.count,
        last_interaction: interactions.maximum(:occurred_at),
        order_count: orders.count,
        total_spent: orders.where(status: 'completed').sum(:total),
        average_order_value: orders.where(status: 'completed').average(:total).to_f.round(2),
        conversion_rate: calculate_conversion_rate(interactions.count, orders.count)
      }

      Rails.logger.debug("Generated channel metrics for customer ID: #{customer.id}, channel: #{channel.name}")
      metrics
    rescue => e
      Rails.logger.error("Failed to generate channel metrics for customer ID: #{customer.id}. Error: #{e.message}")
      {
        interaction_count: 0,
        last_interaction: nil,
        order_count: 0,
        total_spent: 0,
        average_order_value: 0,
        conversion_rate: 0
      }
    end
  end

  def cross_channel_behavior
    Rails.logger.debug("Analyzing cross-channel behavior for customer ID: #{customer.id}")

    begin
      behavior = {
        channel_switching_rate: calculate_channel_switching_rate,
        preferred_journey: most_common_journey_path,
        device_preferences: device_usage_distribution,
        time_preferences: interaction_time_distribution
      }

      Rails.logger.debug("Analyzed cross-channel behavior for customer ID: #{customer.id}")
      behavior
    rescue => e
      Rails.logger.error("Failed to analyze cross-channel behavior for customer ID: #{customer.id}. Error: #{e.message}")
      {
        channel_switching_rate: 0,
        preferred_journey: 'N/A',
        device_preferences: {},
        time_preferences: {}
      }
    end
  end

  def channel_performance_comparison
    Rails.logger.debug("Generating channel performance comparison for customer ID: #{customer.id}")

    begin
      comparison = {}

      customer.channels_used.each do |channel_name|
        channel = SalesChannel.find_by(name: channel_name)
        next unless channel

        comparison[channel_name] = channel_metrics(channel)
      end

      Rails.logger.debug("Generated channel performance comparison for customer ID: #{customer.id}")
      comparison
    rescue => e
      Rails.logger.error("Failed to generate channel performance comparison for customer ID: #{customer.id}. Error: #{e.message}")
      {}
    end
  end

  def engagement_score
    Rails.logger.debug("Calculating engagement score for customer ID: #{customer.id}")

    begin
      # Calculate based on multiple factors
      recency_score = calculate_recency_score
      frequency_score = calculate_frequency_score
      monetary_score = calculate_monetary_score
      channel_diversity_score = calculate_channel_diversity_score

      # Weighted average
      score = (
        recency_score * 0.3 +
        frequency_score * 0.3 +
        monetary_score * 0.25 +
        channel_diversity_score * 0.15
      ).round(2)

      Rails.logger.debug("Calculated engagement score for customer ID: #{customer.id}: #{score}")
      score
    rescue => e
      Rails.logger.error("Failed to calculate engagement score for customer ID: #{customer.id}. Error: #{e.message}")
      0
    end
  end

  def lifetime_value_prediction
    Rails.logger.debug("Predicting lifetime value for customer ID: #{customer.id}")

    begin
      # Simple prediction based on current trends
      current_ltv = customer.total_lifetime_value
      avg_order_value = customer.total_orders_count > 0 ? current_ltv / customer.total_orders_count : 0
      monthly_orders = calculate_monthly_order_frequency

      # Project based on current trends
      projected_monthly_value = avg_order_value * monthly_orders
      projected_annual_value = projected_monthly_value * 12

      # Apply retention factors
      retention_factor = calculate_retention_probability
      predicted_ltv = current_ltv + (projected_annual_value * retention_factor * 2) # 2 years projection

      prediction = {
        current_ltv: current_ltv,
        predicted_ltv: predicted_ltv.round(2),
        confidence: retention_factor,
        factors: {
          avg_order_value: avg_order_value.round(2),
          monthly_frequency: monthly_orders.round(2),
          retention_probability: retention_factor.round(2)
        }
      }

      Rails.logger.debug("Predicted lifetime value for customer ID: #{customer.id}: #{prediction}")
      prediction
    rescue => e
      Rails.logger.error("Failed to predict lifetime value for customer ID: #{customer.id}. Error: #{e.message}")
      {
        current_ltv: customer.total_lifetime_value,
        predicted_ltv: customer.total_lifetime_value,
        confidence: 0,
        factors: {}
      }
    end
  end

  private

  def calculate_conversion_rate(interactions, orders)
    return 0 if interactions.zero?
    ((orders.to_f / interactions) * 100).round(2)
  end

  def calculate_channel_switching_rate
    journeys_with_switches = customer.cross_channel_journeys.where('touchpoint_count > 1').count
    total_journeys = customer.cross_channel_journeys.count

    return 0 if total_journeys.zero?
    ((journeys_with_switches.to_f / total_journeys) * 100).round(2)
  end

  def most_common_journey_path
    paths = customer.cross_channel_journeys.pluck(:journey_data)
      .map { |data| data['channels']&.join(' -> ') }
      .compact

    paths.group_by(&:itself).max_by { |_, v| v.count }&.first || 'N/A'
  end

  def device_usage_distribution
    customer.channel_interactions
      .where.not(interaction_data: nil)
      .pluck(:interaction_data)
      .map { |data| data['device'] }
      .compact
      .group_by(&:itself)
      .transform_values(&:count)
  end

  def interaction_time_distribution
    customer.channel_interactions
      .group_by { |i| i.occurred_at.hour }
      .transform_values(&:count)
  end

  def calculate_recency_score
    return 0 unless customer.last_interaction_at

    days_since_last_interaction = (Time.current - customer.last_interaction_at).to_i / 86400

    case days_since_last_interaction
    when 0..7 then 100
    when 8..30 then 75
    when 31..90 then 50
    when 91..180 then 25
    else 0
    end
  end

  def calculate_frequency_score
    total_interactions = customer.channel_interactions.count

    case total_interactions
    when 0..5 then 20
    when 6..20 then 40
    when 21..50 then 60
    when 51..100 then 80
    else 100
    end
  end

  def calculate_monetary_score
    ltv = customer.total_lifetime_value

    case ltv
    when 0..100 then 20
    when 101..500 then 40
    when 501..2000 then 60
    when 2001..10000 then 80
    else 100
    end
  end

  def calculate_channel_diversity_score
    channels_count = customer.channels_used.count

    case channels_count
    when 0..1 then 20
    when 2 then 50
    when 3..4 then 80
    else 100
    end
  end

  def calculate_monthly_order_frequency
    return 0 if customer.total_orders_count.zero?

    first_order = Order.where(user: customer.user).order(:created_at).first
    return 0 unless first_order

    months_active = (Time.current - first_order.created_at).to_f / (30 * 24 * 3600)
    return 0 if months_active.zero?

    customer.total_orders_count / months_active
  end

  def calculate_retention_probability
    return 0.1 if customer.total_orders_count.zero?

    # Simple retention calculation based on recency and frequency
    recency_score = calculate_recency_score
    frequency_score = calculate_frequency_score

    (recency_score * 0.6 + frequency_score * 0.4) / 100.0
  end
end