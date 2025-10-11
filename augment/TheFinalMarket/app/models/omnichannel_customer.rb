class OmnichannelCustomer < ApplicationRecord
  belongs_to :user
  has_many :channel_interactions
  has_many :channel_preferences
  has_many :cross_channel_journeys
  
  validates :user, presence: true, uniqueness: true
  
  # Get unified customer profile
  def unified_profile
    {
      user_id: user.id,
      total_orders: total_orders_count,
      total_spent: total_lifetime_value,
      favorite_channel: favorite_channel,
      channels_used: channels_used,
      last_interaction: last_interaction_at,
      customer_segment: customer_segment,
      preferences: unified_preferences,
      journey_summary: journey_summary
    }
  end
  
  # Get favorite channel
  def favorite_channel
    channel_interactions
      .group(:sales_channel_id)
      .count
      .max_by { |_, count| count }
      &.first
      &.then { |id| SalesChannel.find(id).name }
  end
  
  # Get all channels used
  def channels_used
    channel_interactions
      .joins(:sales_channel)
      .distinct
      .pluck('sales_channels.name')
  end
  
  # Get total orders across all channels
  def total_orders_count
    Order.where(user: user).count
  end
  
  # Get total lifetime value across all channels
  def total_lifetime_value
    Order.where(user: user, status: 'completed').sum(:total)
  end
  
  # Get customer segment
  def customer_segment
    ltv = total_lifetime_value
    orders = total_orders_count
    
    if ltv > 10000 && orders > 20
      'vip'
    elsif ltv > 5000 && orders > 10
      'high_value'
    elsif ltv > 1000 && orders > 5
      'regular'
    elsif orders > 0
      'new'
    else
      'prospect'
    end
  end
  
  # Get unified preferences across channels
  def unified_preferences
    prefs = {}
    
    channel_preferences.each do |cp|
      prefs[cp.sales_channel.name] = cp.preferences_data
    end
    
    # Merge and find common preferences
    {
      by_channel: prefs,
      common: find_common_preferences(prefs)
    }
  end
  
  # Track interaction
  def track_interaction(channel, interaction_type, metadata = {})
    channel_interactions.create!(
      sales_channel: channel,
      interaction_type: interaction_type,
      interaction_data: metadata,
      occurred_at: Time.current
    )
    
    update!(last_interaction_at: Time.current)
  end
  
  # Get customer journey
  def journey_summary
    journeys = cross_channel_journeys.order(started_at: :desc).limit(10)
    
    {
      total_journeys: cross_channel_journeys.count,
      completed_journeys: cross_channel_journeys.where(completed: true).count,
      average_touchpoints: cross_channel_journeys.average(:touchpoint_count).to_f.round(2),
      average_duration: average_journey_duration,
      recent_journeys: journeys.map(&:summary)
    }
  end
  
  # Start a new journey
  def start_journey(channel, intent)
    cross_channel_journeys.create!(
      sales_channel: channel,
      intent: intent,
      started_at: Time.current,
      touchpoint_count: 1,
      journey_data: { channels: [channel.name] }
    )
  end
  
  # Get channel-specific metrics
  def channel_metrics(channel)
    interactions = channel_interactions.where(sales_channel: channel)
    orders = Order.where(user: user, sales_channel: channel)
    
    {
      interaction_count: interactions.count,
      last_interaction: interactions.maximum(:occurred_at),
      order_count: orders.count,
      total_spent: orders.where(status: 'completed').sum(:total),
      average_order_value: orders.where(status: 'completed').average(:total).to_f.round(2),
      conversion_rate: calculate_conversion_rate(interactions.count, orders.count)
    }
  end
  
  # Get cross-channel behavior
  def cross_channel_behavior
    {
      channel_switching_rate: calculate_channel_switching_rate,
      preferred_journey: most_common_journey_path,
      device_preferences: device_usage_distribution,
      time_preferences: interaction_time_distribution
    }
  end
  
  # Sync customer data across channels
  def sync_across_channels!
    profile_data = {
      name: user.name,
      email: user.email,
      phone: user.phone,
      preferences: unified_preferences[:common],
      segment: customer_segment,
      lifetime_value: total_lifetime_value
    }
    
    SalesChannel.active_channels.each do |channel|
      # This would integrate with each channel's API
      # For now, just update our records
      pref = channel_preferences.find_or_initialize_by(sales_channel: channel)
      pref.update!(
        preferences_data: profile_data,
        last_synced_at: Time.current
      )
    end
  end
  
  # Get next best action
  def next_best_action
    # AI-powered recommendation for next best action
    recent_behavior = channel_interactions.order(occurred_at: :desc).limit(10)
    
    if recent_behavior.where(interaction_type: 'cart_abandonment').exists?
      { action: 'send_cart_reminder', channel: favorite_channel, priority: 'high' }
    elsif total_orders_count == 0
      { action: 'send_welcome_offer', channel: favorite_channel, priority: 'medium' }
    elsif (Time.current - last_interaction_at) > 30.days
      { action: 'send_winback_campaign', channel: favorite_channel, priority: 'medium' }
    else
      { action: 'send_personalized_recommendations', channel: favorite_channel, priority: 'low' }
    end
  end
  
  private
  
  def find_common_preferences(channel_prefs)
    # Find preferences that are common across channels
    return {} if channel_prefs.empty?
    
    common = {}
    first_prefs = channel_prefs.values.first || {}
    
    first_prefs.each do |key, value|
      if channel_prefs.values.all? { |prefs| prefs[key] == value }
        common[key] = value
      end
    end
    
    common
  end
  
  def average_journey_duration
    journeys = cross_channel_journeys.where.not(completed_at: nil)
    return 0 if journeys.empty?
    
    total_duration = journeys.sum do |journey|
      (journey.completed_at - journey.started_at).to_i
    end
    
    (total_duration / journeys.count / 3600.0).round(2) # in hours
  end
  
  def calculate_conversion_rate(interactions, orders)
    return 0 if interactions.zero?
    ((orders.to_f / interactions) * 100).round(2)
  end
  
  def calculate_channel_switching_rate
    journeys_with_switches = cross_channel_journeys.where('touchpoint_count > 1').count
    total_journeys = cross_channel_journeys.count
    
    return 0 if total_journeys.zero?
    ((journeys_with_switches.to_f / total_journeys) * 100).round(2)
  end
  
  def most_common_journey_path
    # Analyze journey data to find most common path
    paths = cross_channel_journeys.pluck(:journey_data)
                                  .map { |data| data['channels']&.join(' -> ') }
                                  .compact
    
    paths.group_by(&:itself).max_by { |_, v| v.count }&.first || 'N/A'
  end
  
  def device_usage_distribution
    channel_interactions
      .where.not(interaction_data: nil)
      .pluck(:interaction_data)
      .map { |data| data['device'] }
      .compact
      .group_by(&:itself)
      .transform_values(&:count)
  end
  
  def interaction_time_distribution
    channel_interactions
      .group_by { |i| i.occurred_at.hour }
      .transform_values(&:count)
  end
end

