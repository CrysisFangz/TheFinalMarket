class OmnichannelCustomer < ApplicationRecord
  belongs_to :user
  has_many :channel_interactions
  has_many :channel_preferences
  has_many :cross_channel_journeys
  
  validates :user, presence: true, uniqueness: true
  
  # Get unified customer profile
  def unified_profile
    profile_service.unified_profile
  end

  # Get favorite channel
  def favorite_channel
    profile_service.favorite_channel
  end

  # Get all channels used
  def channels_used
    profile_service.channels_used
  end

  # Get total orders across all channels
  def total_orders_count
    profile_service.total_orders_count
  end

  # Get total lifetime value across all channels
  def total_lifetime_value
    profile_service.total_lifetime_value
  end

  # Get customer segment
  def customer_segment
    profile_service.customer_segment
  end

  # Get unified preferences across channels
  def unified_preferences
    profile_service.unified_preferences
  end
  
  # Track interaction
  def track_interaction(channel, interaction_type, metadata = {})
    journey_service.track_interaction(channel, interaction_type, metadata)
  end

  # Get customer journey
  def journey_summary
    journey_service.journey_summary
  end

  # Start a new journey
  def start_journey(channel, intent)
    journey_service.start_journey(channel, intent)
  end
  
  # Get channel-specific metrics
  def channel_metrics(channel)
    analytics_service.channel_metrics(channel)
  end

  # Get cross-channel behavior
  def cross_channel_behavior
    analytics_service.cross_channel_behavior
  end

  # Sync customer data across channels
  def sync_across_channels!
    sync_service.sync_across_channels!
  end

  # Get next best action
  def next_best_action
    recommendation_service.next_best_action
  end

  # Additional methods that delegate to services
  def engagement_score
    analytics_service.engagement_score
  end

  def lifetime_value_prediction
    analytics_service.lifetime_value_prediction
  end

  def recommended_products(limit = 10)
    recommendation_service.recommended_products(limit)
  end

  def recommended_channel_for_action(action_type)
    recommendation_service.recommended_channel_for_action(action_type)
  end

  def personalized_campaigns
    recommendation_service.personalized_campaigns
  end

  def optimal_send_time
    recommendation_service.optimal_send_time
  end

  def channel_performance_comparison
    analytics_service.channel_performance_comparison
  end

  def sync_to_channel(channel, profile_data = nil)
    sync_service.sync_to_channel(channel, profile_data)
  end

  def sync_from_channel(channel, channel_data)
    sync_service.sync_from_channel(channel, channel_data)
  end

  def sync_preferences_only!
    sync_service.sync_preferences_only!
  end

  def validate_channel_sync_status
    sync_service.validate_channel_sync_status
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

