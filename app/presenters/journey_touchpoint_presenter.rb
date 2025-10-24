class JourneyTouchpointPresenter
  include CircuitBreaker
  include Retryable

  def initialize(touchpoint)
    @touchpoint = touchpoint
  end

  def as_json(options = {})
    cache_key = "journey_touchpoint_presenter:#{@touchpoint.id}:#{@touchpoint.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('journey_touchpoint_presenter') do
        with_retry do
          {
            id: @touchpoint.id,
            action: @touchpoint.action,
            occurred_at: @touchpoint.occurred_at,
            touchpoint_data: @touchpoint.touchpoint_data,
            created_at: @touchpoint.created_at,
            updated_at: @touchpoint.updated_at,
            sales_channel: sales_channel_data,
            cross_channel_journey: journey_data,
            summary: summary_data,
            analytics: analytics_data,
            engagement_metrics: engagement_metrics
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

  def to_analytics_response
    as_json.merge(
      analytics_data: {
        journey_stage: determine_journey_stage,
        engagement_score: calculate_engagement_score,
        conversion_probability: calculate_conversion_probability,
        channel_effectiveness: calculate_channel_effectiveness,
        time_from_journey_start: time_from_journey_start,
        sequence_position: sequence_position
      }
    )
  end

  private

  def sales_channel_data
    Rails.cache.fetch("touchpoint_channel:#{@touchpoint.sales_channel_id}", expires_in: 30.minutes) do
      with_circuit_breaker('channel_data') do
        with_retry do
          {
            id: @touchpoint.sales_channel.id,
            name: @touchpoint.sales_channel.name,
            channel_type: @touchpoint.sales_channel.channel_type,
            status: @touchpoint.sales_channel.status,
            configuration: @touchpoint.sales_channel.configuration
          }
        end
      end
    end
  end

  def journey_data
    Rails.cache.fetch("touchpoint_journey:#{@touchpoint.cross_channel_journey_id}", expires_in: 15.minutes) do
      with_circuit_breaker('journey_data') do
        with_retry do
          journey = @touchpoint.cross_channel_journey

          {
            id: journey.id,
            user_id: journey.user_id,
            status: journey.status,
            started_at: journey.started_at,
            completed_at: journey.completed_at,
            total_touchpoints: journey.journey_touchpoints.count,
            channels_used: journey.journey_touchpoints.includes(:sales_channel).map { |t| t.sales_channel.channel_type }.uniq
          }
        end
      end
    end
  end

  def summary_data
    Rails.cache.fetch("touchpoint_summary:#{@touchpoint.id}", expires_in: 20.minutes) do
      with_circuit_breaker('summary_data') do
        with_retry do
          JourneyTouchpointManagementService.get_touchpoint_summary(@touchpoint)
        end
      end
    end
  end

  def analytics_data
    Rails.cache.fetch("touchpoint_analytics:#{@touchpoint.id}", expires_in: 15.minutes) do
      with_circuit_breaker('analytics_data') do
        with_retry do
          journey_analysis = JourneyAnalyticsService.analyze_journey_performance(@touchpoint.cross_channel_journey_id)
          channel_insights = JourneyAnalyticsService.get_channel_insights(@touchpoint.sales_channel_id)

          {
            journey_performance: journey_analysis,
            channel_insights: channel_insights,
            touchpoint_impact: calculate_touchpoint_impact,
            user_behavior: analyze_user_behavior,
            conversion_funnel_position: determine_funnel_position
          }
        end
      end
    end
  end

  def engagement_metrics
    Rails.cache.fetch("touchpoint_engagement:#{@touchpoint.id}", expires_in: 10.minutes) do
      with_circuit_breaker('engagement_metrics') do
        with_retry do
          {
            engagement_score: calculate_engagement_score,
            interaction_quality: assess_interaction_quality,
            user_intent: determine_user_intent,
            session_context: get_session_context,
            device_info: extract_device_info,
            time_spent: estimate_time_spent
          }
        end
      end
    end
  end

  def determine_journey_stage
    case @touchpoint.action
    when 'product_view', 'category_browse', 'search'
      'awareness'
    when 'add_to_cart', 'wishlist_add', 'product_comparison'
      'consideration'
    when 'checkout_start', 'purchase', 'payment'
      'decision'
    when 'review', 'repeat_purchase', 'referral'
      'loyalty'
    else
      'engagement'
    end
  end

  def calculate_engagement_score
    base_score = 10

    # Higher score for more engaging actions
    engagement_weights = {
      'purchase' => 50,
      'review' => 30,
      'add_to_cart' => 20,
      'product_view' => 10,
      'category_browse' => 5,
      'search' => 8,
      'checkout_start' => 40,
      'wishlist_add' => 15,
      'repeat_purchase' => 45,
      'referral' => 35
    }

    base_score + (engagement_weights[@touchpoint.action.to_s] || 5)
  end

  def calculate_conversion_probability
    Rails.cache.fetch("touchpoint_conversion_prob:#{@touchpoint.id}", expires_in: 15.minutes) do
      with_circuit_breaker('conversion_probability') do
        with_retry do
          # Calculate probability of conversion based on action and journey context
          action_probabilities = {
            'purchase' => 100,
            'checkout_start' => 80,
            'add_to_cart' => 30,
            'wishlist_add' => 25,
            'product_view' => 5,
            'category_browse' => 3,
            'search' => 8,
            'review' => 60,
            'repeat_purchase' => 90
          }

          base_probability = action_probabilities[@touchpoint.action.to_s] || 10

          # Adjust based on journey stage and channel effectiveness
          stage_multiplier = case determine_journey_stage
                            when 'decision'
                              1.5
                            when 'loyalty'
                              2.0
                            when 'consideration'
                              1.2
                            else
                              1.0
                            end

          channel_effectiveness = calculate_channel_effectiveness
          channel_multiplier = channel_effectiveness / 50.0 # Normalize to 1.0

          probability = base_probability * stage_multiplier * channel_multiplier
          [probability, 100].min
        end
      end
    end
  end

  def calculate_channel_effectiveness
    channel_insights = JourneyAnalyticsService.get_channel_insights(@touchpoint.sales_channel_id)

    # Calculate effectiveness based on conversion impact and engagement
    conversion_rate = channel_insights[:conversion_impact][:conversion_rate] || 0
    engagement_score = channel_insights[:user_engagement_patterns][:session_frequency] || 1

    (conversion_rate + engagement_score * 10) / 2
  end

  def time_from_journey_start
    journey = @touchpoint.cross_channel_journey
    touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(journey.id)

    return 0 if touchpoints.empty?

    first_touchpoint = touchpoints.min_by(&:occurred_at)
    @touchpoint.occurred_at - first_touchpoint.occurred_at
  end

  def sequence_position
    touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(@touchpoint.cross_channel_journey_id)
    sorted_touchpoints = touchpoints.sort_by(&:occurred_at)

    sorted_touchpoints.index(@touchpoint) + 1
  end

  def calculate_touchpoint_impact
    {
      conversion_contribution: calculate_conversion_contribution,
      engagement_value: calculate_engagement_score,
      channel_amplification: calculate_channel_amplification,
      journey_progression: measure_journey_progression
    }
  end

  def analyze_user_behavior
    {
      intent_clarity: assess_intent_clarity,
      decision_stage: determine_decision_stage,
      channel_preference: identify_channel_preference,
      engagement_level: determine_engagement_level,
      purchase_readiness: assess_purchase_readiness
    }
  end

  def determine_funnel_position
    stage = determine_journey_stage

    {
      stage: stage,
      stage_number: funnel_stage_number(stage),
      progress_percentage: calculate_funnel_progress,
      next_expected_actions: predict_next_actions(stage)
    }
  end

  def assess_interaction_quality
    quality_score = 50 # Base score

    # Higher quality for specific, intentional actions
    if @touchpoint.touchpoint_data.present?
      quality_score += 20
    end

    # Higher quality for actions that indicate research
    research_actions = ['product_comparison', 'review_read', 'detailed_view']
    if research_actions.include?(@touchpoint.action)
      quality_score += 15
    end

    # Higher quality for actions with longer engagement
    if @touchpoint.touchpoint_data&.dig('time_spent').to_i > 60
      quality_score += 15
    end

    [quality_score, 100].min
  end

  def determine_user_intent
    intent_indicators = {
      'purchase' => 'transactional',
      'checkout_start' => 'transactional',
      'add_to_cart' => 'consideration',
      'wishlist_add' => 'consideration',
      'product_view' => 'research',
      'category_browse' => 'exploration',
      'search' => 'research',
      'review' => 'loyalty',
      'repeat_purchase' => 'loyalty',
      'referral' => 'advocacy'
    }

    intent_indicators[@touchpoint.action.to_s] || 'unknown'
  end

  def get_session_context
    {
      session_id: @touchpoint.touchpoint_data&.dig('session_id'),
      user_agent: @touchpoint.touchpoint_data&.dig('user_agent'),
      referrer: @touchpoint.touchpoint_data&.dig('referrer'),
      entry_point: determine_entry_point,
      exit_intent: assess_exit_intent
    }
  end

  def extract_device_info
    user_agent = @touchpoint.touchpoint_data&.dig('user_agent') || ''

    {
      device_type: detect_device_type(user_agent),
      browser: extract_browser(user_agent),
      operating_system: extract_os(user_agent),
      screen_resolution: @touchpoint.touchpoint_data&.dig('screen_resolution'),
      is_mobile: is_mobile_device?(user_agent)
    }
  end

  def estimate_time_spent
    # Estimate time spent based on action type and available data
    time_estimates = {
      'purchase' => 300, # 5 minutes
      'checkout_start' => 180, # 3 minutes
      'add_to_cart' => 30, # 30 seconds
      'product_view' => 45, # 45 seconds
      'category_browse' => 60, # 1 minute
      'search' => 20, # 20 seconds
      'review' => 120 # 2 minutes
    }

    explicit_time = @touchpoint.touchpoint_data&.dig('time_spent')&.to_i
    explicit_time || time_estimates[@touchpoint.action.to_s] || 30
  end

  def calculate_conversion_contribution
    # Calculate how much this touchpoint contributes to conversion
    action_weights = {
      'purchase' => 100,
      'checkout_start' => 80,
      'add_to_cart' => 40,
      'wishlist_add' => 30,
      'product_view' => 10,
      'search' => 15,
      'review' => 50
    }

    position_bonus = sequence_position <= 3 ? 20 : 0
    channel_bonus = calculate_channel_effectiveness > 70 ? 15 : 0

    base_contribution = action_weights[@touchpoint.action.to_s] || 5
    base_contribution + position_bonus + channel_bonus
  end

  def calculate_channel_amplification
    # Calculate how this channel amplifies the overall journey
    channel_effectiveness = calculate_channel_effectiveness
    channel_stickiness = get_channel_stickiness

    (channel_effectiveness + channel_stickiness) / 2
  end

  def measure_journey_progression
    stage = determine_journey_stage
    stage_numbers = { 'awareness' => 1, 'consideration' => 2, 'decision' => 3, 'loyalty' => 4 }

    {
      current_stage: stage,
      stage_number: stage_numbers[stage] || 0,
      progress_percentage: (stage_numbers[stage] || 0) * 25,
      is_progressing: is_progressing?,
      next_milestone: next_milestone(stage)
    }
  end

  def assess_intent_clarity
    clarity_indicators = {
      'purchase' => 'very_clear',
      'checkout_start' => 'clear',
      'add_to_cart' => 'moderate',
      'wishlist_add' => 'moderate',
      'product_view' => 'unclear',
      'search' => 'unclear',
      'category_browse' => 'unclear'
    }

    clarity_indicators[@touchpoint.action.to_s] || 'unknown'
  end

  def determine_decision_stage
    stage = determine_journey_stage

    case stage
    when 'awareness'
      'early'
    when 'consideration'
      'middle'
    when 'decision'
      'late'
    when 'loyalty'
      'post_purchase'
    else
      'unknown'
    end
  end

  def identify_channel_preference
    journey = @touchpoint.cross_channel_journey
    touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(journey.id)

    channel_usage = touchpoints.group_by { |t| t.sales_channel.channel_type }
    most_used_channel = channel_usage.max_by { |_, touches| touches.count }&.first

    {
      preferred_channel: most_used_channel,
      channel_loyalty: calculate_channel_loyalty(channel_usage),
      multi_channel_user: channel_usage.keys.count > 1
    }
  end

  def determine_engagement_level
    score = calculate_engagement_score

    case score
    when 0..20
      'low'
    when 21..50
      'medium'
    when 51..80
      'high'
    else
      'very_high'
    end
  end

  def assess_purchase_readiness
    readiness_score = 0

    # Action readiness
    action_scores = {
      'purchase' => 100,
      'checkout_start' => 90,
      'add_to_cart' => 60,
      'wishlist_add' => 50,
      'product_view' => 20,
      'search' => 30
    }

    readiness_score += action_scores[@touchpoint.action.to_s] || 10

    # Journey stage readiness
    stage_scores = {
      'awareness' => 20,
      'consideration' => 60,
      'decision' => 90,
      'loyalty' => 80
    }

    readiness_score += stage_scores[determine_journey_stage] || 30

    # Channel effectiveness readiness
    readiness_score += (calculate_channel_effectiveness / 2).to_i

    case readiness_score
    when 0..30
      'not_ready'
    when 31..60
      'considering'
    when 61..90
      'ready'
    else
      'immediate'
    end
  end

  def determine_entry_point
    journey = @touchpoint.cross_channel_journey
    touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(journey.id)

    return 'unknown' if touchpoints.empty?

    first_touchpoint = touchpoints.min_by(&:occurred_at)
    first_touchpoint.sales_channel.channel_type
  end

  def assess_exit_intent
    # Analyze if this touchpoint indicates exit intent
    exit_indicators = ['bounce', 'quick_exit', 'negative_feedback']

    exit_indicators.include?(@touchpoint.action) || time_spent < 10
  end

  def detect_device_type(user_agent)
    return 'unknown' if user_agent.blank?

    if user_agent.include?('Mobile')
      'mobile'
    elsif user_agent.include?('Tablet')
      'tablet'
    else
      'desktop'
    end
  end

  def extract_browser(user_agent)
    return 'unknown' if user_agent.blank?

    browsers = ['Chrome', 'Firefox', 'Safari', 'Edge', 'Opera']
    detected_browser = browsers.find { |browser| user_agent.include?(browser) }
    detected_browser || 'unknown'
  end

  def extract_os(user_agent)
    return 'unknown' if user_agent.blank?

    operating_systems = ['Windows', 'macOS', 'Linux', 'Android', 'iOS']
    detected_os = operating_systems.find { |os| user_agent.include?(os) }
    detected_os || 'unknown'
  end

  def is_mobile_device?(user_agent)
    return false if user_agent.blank?

    user_agent.include?('Mobile') || user_agent.include?('Android') || user_agent.include?('iPhone')
  end

  def is_progressing?
    journey = @touchpoint.cross_channel_journey
    touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(journey.id)

    return false if touchpoints.count < 2

    current_stage_num = funnel_stage_number(determine_journey_stage)
    previous_touchpoint = touchpoints.sort_by(&:occurred_at).last(2).first
    previous_stage_num = funnel_stage_number(determine_journey_stage_from_action(previous_touchpoint.action))

    current_stage_num >= previous_stage_num
  end

  def next_milestone(current_stage)
    case current_stage
    when 'awareness'
      'add_to_cart'
    when 'consideration'
      'checkout_start'
    when 'decision'
      'purchase'
    when 'loyalty'
      'review'
    else
      'product_view'
    end
  end

  def funnel_stage_number(stage)
    stage_numbers = { 'awareness' => 1, 'consideration' => 2, 'decision' => 3, 'loyalty' => 4 }
    stage_numbers[stage] || 0
  end

  def determine_journey_stage_from_action(action)
    case action
    when 'product_view', 'category_browse', 'search'
      'awareness'
    when 'add_to_cart', 'wishlist_add', 'product_comparison'
      'consideration'
    when 'checkout_start', 'purchase', 'payment'
      'decision'
    when 'review', 'repeat_purchase', 'referral'
      'loyalty'
    else
      'engagement'
    end
  end

  def calculate_funnel_progress
    stage_numbers = { 'awareness' => 1, 'consideration' => 2, 'decision' => 3, 'loyalty' => 4 }
    current_stage_num = stage_numbers[determine_journey_stage] || 0

    (current_stage_num * 25)
  end

  def predict_next_actions(current_stage)
    next_actions = case current_stage
                  when 'awareness'
                    ['product_view', 'add_to_cart', 'search']
                  when 'consideration'
                    ['add_to_cart', 'checkout_start', 'product_comparison']
                  when 'decision'
                    ['checkout_start', 'purchase', 'payment']
                  when 'loyalty'
                    ['review', 'repeat_purchase', 'referral']
                  else
                    ['product_view', 'category_browse']
                  end

    next_actions
  end

  def get_channel_stickiness
    channel_insights = JourneyAnalyticsService.get_channel_insights(@touchpoint.sales_channel_id)
    channel_insights[:channel_stickiness][@touchpoint.sales_channel.channel_type][:stickiness_score] || 0
  end

  def calculate_channel_loyalty(channel_usage)
    most_used = channel_usage.max_by { |_, touches| touches.count }
    return 'none' if most_used.nil?

    channel_type = most_used.first
    usage_count = most_used.last.count

    case usage_count
    when 1
      'single_use'
    when 2..3
      'moderate'
    when 4..7
      'loyal'
    else
      'highly_loyal'
    end
  end
end