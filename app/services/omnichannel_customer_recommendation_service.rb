class OmnichannelCustomerRecommendationService
  attr_reader :customer

  def initialize(customer)
    @customer = customer
  end

  def next_best_action
    Rails.logger.debug("Calculating next best action for customer ID: #{customer.id}")

    begin
      recent_behavior = customer.channel_interactions.order(occurred_at: :desc).limit(10)

      action = if recent_behavior.where(interaction_type: 'cart_abandonment').exists?
        generate_cart_reminder_action
      elsif customer.total_orders_count == 0
        generate_welcome_action
      elsif (Time.current - customer.last_interaction_at) > 30.days
        generate_winback_action
      else
        generate_personalized_recommendations_action
      end

      Rails.logger.info("Generated next best action for customer ID: #{customer.id}: #{action}")
      action
    rescue => e
      Rails.logger.error("Failed to calculate next best action for customer ID: #{customer.id}. Error: #{e.message}")
      {
        action: 'send_generic_notification',
        channel: customer.favorite_channel || 'web',
        priority: 'low',
        error: e.message
      }
    end
  end

  def recommended_products(limit = 10)
    Rails.logger.debug("Generating product recommendations for customer ID: #{customer.id}")

    begin
      # Analyze purchase history and preferences
      purchased_product_ids = Order.where(user: customer.user, status: 'completed')
        .joins(:order_items)
        .pluck('order_items.product_id')
        .uniq

      # Get products from preferred categories
      preferred_categories = analyze_preferred_categories

      # Find similar products or trending items
      recommended_products = Product.where(category: preferred_categories)
        .where.not(id: purchased_product_ids)
        .order(created_at: :desc)
        .limit(limit)

      Rails.logger.debug("Generated #{recommended_products.count} product recommendations for customer ID: #{customer.id}")
      recommended_products
    rescue => e
      Rails.logger.error("Failed to generate product recommendations for customer ID: #{customer.id}. Error: #{e.message}")
      Product.none
    end
  end

  def recommended_channel_for_action(action_type)
    Rails.logger.debug("Recommending channel for action: #{action_type} for customer ID: #{customer.id}")

    begin
      channel_scores = {}

      customer.channels_used.each do |channel_name|
        channel = SalesChannel.find_by(name: channel_name)
        next unless channel

        metrics = customer.channel_metrics(channel)
        score = calculate_channel_score_for_action(channel, action_type, metrics)
        channel_scores[channel_name] = score
      end

      best_channel = channel_scores.max_by { |_, score| score }&.first
      best_channel ||= customer.favorite_channel || 'web'

      Rails.logger.debug("Recommended channel '#{best_channel}' for action '#{action_type}' for customer ID: #{customer.id}")
      best_channel
    rescue => e
      Rails.logger.error("Failed to recommend channel for action: #{action_type} for customer ID: #{customer.id}. Error: #{e.message}")
      customer.favorite_channel || 'web'
    end
  end

  def personalized_campaigns
    Rails.logger.debug("Generating personalized campaigns for customer ID: #{customer.id}")

    begin
      campaigns = []

      case customer.customer_segment
      when 'vip'
        campaigns << generate_vip_campaign
      when 'high_value'
        campaigns << generate_high_value_campaign
      when 'regular'
        campaigns << generate_regular_campaign
      when 'new'
        campaigns << generate_new_customer_campaign
      else
        campaigns << generate_prospect_campaign
      end

      # Add behavior-based campaigns
      campaigns.concat(generate_behavior_based_campaigns)

      Rails.logger.debug("Generated #{campaigns.count} personalized campaigns for customer ID: #{customer.id}")
      campaigns
    rescue => e
      Rails.logger.error("Failed to generate personalized campaigns for customer ID: #{customer.id}. Error: #{e.message}")
      []
    end
  end

  def optimal_send_time
    Rails.logger.debug("Calculating optimal send time for customer ID: #{customer.id}")

    begin
      time_preferences = customer.interaction_time_distribution

      if time_preferences.empty?
        # Default to business hours if no data
        return 14 # 2 PM
      end

      # Find hour with highest interaction frequency
      optimal_hour = time_preferences.max_by { |_, count| count }&.first

      # Adjust for timezone and business hours
      optimal_hour = adjust_for_business_hours(optimal_hour)

      Rails.logger.debug("Optimal send time for customer ID: #{customer.id}: #{optimal_hour}:00")
      optimal_hour
    rescue => e
      Rails.logger.error("Failed to calculate optimal send time for customer ID: #{customer.id}. Error: #{e.message}")
      14 # Default to 2 PM
    end
  end

  private

  def generate_cart_reminder_action
    {
      action: 'send_cart_reminder',
      channel: recommended_channel_for_action('cart_reminder'),
      priority: 'high',
      timing: optimal_send_time,
      message: 'You have items in your cart. Complete your purchase now!'
    }
  end

  def generate_welcome_action
    {
      action: 'send_welcome_offer',
      channel: recommended_channel_for_action('welcome'),
      priority: 'medium',
      timing: optimal_send_time,
      message: 'Welcome! Enjoy this special offer on your first purchase.'
    }
  end

  def generate_winback_action
    {
      action: 'send_winback_campaign',
      channel: recommended_channel_for_action('winback'),
      priority: 'medium',
      timing: optimal_send_time,
      message: 'We miss you! Come back and enjoy this special offer.'
    }
  end

  def generate_personalized_recommendations_action
    {
      action: 'send_personalized_recommendations',
      channel: recommended_channel_for_action('recommendations'),
      priority: 'low',
      timing: optimal_send_time,
      message: 'Here are some personalized recommendations for you!'
    }
  end

  def analyze_preferred_categories
    Rails.logger.debug("Analyzing preferred categories for customer ID: #{customer.id}")

    begin
      # Get categories from purchase history
      purchased_categories = Order.where(user: customer.user, status: 'completed')
        .joins(:order_items => :product)
        .pluck('products.category_id')
        .uniq

      # If no purchase history, use interaction data
      if purchased_categories.empty?
        interaction_categories = customer.channel_interactions
          .where.not(interaction_data: nil)
          .pluck(:interaction_data)
          .map { |data| data['category_id'] }
          .compact
          .uniq

        purchased_categories = interaction_categories unless interaction_categories.empty?
      end

      purchased_categories
    rescue => e
      Rails.logger.error("Failed to analyze preferred categories for customer ID: #{customer.id}. Error: #{e.message}")
      []
    end
  end

  def calculate_channel_score_for_action(channel, action_type, metrics)
    Rails.logger.debug("Calculating channel score for action: #{action_type} on channel: #{channel.name}")

    begin
      score = 0

      # Base score from historical performance
      score += metrics[:conversion_rate] * 0.4
      score += (metrics[:interaction_count] / 100.0) * 0.3
      score += (metrics[:average_order_value] / 1000.0) * 0.3

      # Adjust based on action type
      case action_type
      when 'cart_reminder'
        score += 20 if channel.name.downcase.include?('email')
      when 'welcome'
        score += 15 if channel.name.downcase.include?('mobile')
      when 'winback'
        score += 10 if channel.name.downcase.include?('email') || channel.name.downcase.include?('sms')
      when 'recommendations'
        score += 10 if channel.name.downcase.include?('web') || channel.name.downcase.include?('mobile')
      end

      # Recency bonus
      if metrics[:last_interaction] && (Time.current - metrics[:last_interaction]) < 7.days
        score += 10
      end

      score.round(2)
    rescue => e
      Rails.logger.error("Failed to calculate channel score for action: #{action_type}. Error: #{e.message}")
      0
    end
  end

  def generate_vip_campaign
    {
      name: 'VIP Exclusive Offers',
      type: 'exclusive',
      channel: recommended_channel_for_action('vip'),
      content: 'Exclusive VIP offers and early access to new products.',
      priority: 'high'
    }
  end

  def generate_high_value_campaign
    {
      name: 'Premium Customer Rewards',
      type: 'rewards',
      channel: recommended_channel_for_action('rewards'),
      content: 'Thank you for being a valued customer. Enjoy these premium rewards.',
      priority: 'medium'
    }
  end

  def generate_regular_campaign
    {
      name: 'Loyalty Program',
      type: 'loyalty',
      channel: recommended_channel_for_action('loyalty'),
      content: 'Join our loyalty program and earn points on every purchase.',
      priority: 'medium'
    }
  end

  def generate_new_customer_campaign
    {
      name: 'Welcome Series',
      type: 'welcome',
      channel: recommended_channel_for_action('welcome'),
      content: 'Welcome to our platform! Here are some tips to get started.',
      priority: 'high'
    }
  end

  def generate_prospect_campaign
    {
      name: 'Awareness Campaign',
      type: 'awareness',
      channel: recommended_channel_for_action('awareness'),
      content: 'Discover our amazing products and services.',
      priority: 'low'
    }
  end

  def generate_behavior_based_campaigns
    campaigns = []

    # Cart abandonment campaign
    if customer.channel_interactions.where(interaction_type: 'cart_abandonment').exists?
      campaigns << {
        name: 'Cart Recovery',
        type: 'recovery',
        channel: recommended_channel_for_action('recovery'),
        content: 'Complete your purchase and save 10%!',
        priority: 'high'
      }
    end

    # Seasonal campaign based on time preferences
    current_month = Time.current.month
    if [11, 12].include?(current_month) # Holiday season
      campaigns << {
        name: 'Holiday Special',
        type: 'seasonal',
        channel: recommended_channel_for_action('seasonal'),
        content: 'Holiday specials and gift ideas for you.',
        priority: 'medium'
      }
    end

    campaigns
  end

  def adjust_for_business_hours(hour)
    # Adjust to business hours (9 AM - 6 PM)
    case hour
    when 0..8 then 9
    when 19..23 then 18
    else hour
    end
  end
end