class JourneyAnalyticsService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'journey_analytics'
  CACHE_TTL = 15.minutes

  def self.analyze_journey_performance(journey_id)
    cache_key = "#{CACHE_KEY_PREFIX}:performance:#{journey_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          journey = CrossChannelJourney.find(journey_id)
          touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(journey_id)

          analysis = {
            total_touchpoints: touchpoints.count,
            channels_used: touchpoints.map { |t| t.sales_channel.channel_type }.uniq,
            journey_duration: calculate_journey_duration(touchpoints),
            conversion_funnel: build_conversion_funnel(touchpoints),
            channel_effectiveness: calculate_channel_effectiveness(touchpoints),
            engagement_score: calculate_engagement_score(touchpoints),
            drop_off_points: identify_drop_off_points(touchpoints),
            optimal_path: determine_optimal_path(touchpoints)
          }

          EventPublisher.publish('journey_analytics.performance_analyzed', {
            journey_id: journey_id,
            user_id: journey.user_id,
            total_touchpoints: analysis[:total_touchpoints],
            channels_used: analysis[:channels_used].count,
            journey_duration: analysis[:journey_duration],
            engagement_score: analysis[:engagement_score],
            analyzed_at: Time.current
          })

          analysis
        end
      end
    end
  end

  def self.get_channel_insights(channel_id, start_date = 30.days.ago, end_date = Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:insights:#{channel_id}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_channel(channel_id)
                                        .where(occurred_at: start_date..end_date)

          insights = {
            touchpoint_volume: touchpoints.count,
            unique_journeys: touchpoints.distinct.count(:cross_channel_journey_id),
            action_distribution: touchpoints.group(:action).count,
            peak_activity_hours: touchpoints.group_by_hour_of_day(:occurred_at).count,
            user_engagement_patterns: analyze_engagement_patterns(touchpoints),
            conversion_impact: measure_conversion_impact(touchpoints),
            channel_stickiness: calculate_channel_stickiness(touchpoints)
          }

          EventPublisher.publish('journey_analytics.channel_insights_generated', {
            channel_id: channel_id,
            start_date: start_date,
            end_date: end_date,
            touchpoint_volume: insights[:touchpoint_volume],
            unique_journeys: insights[:unique_journeys],
            generated_at: Time.current
          })

          insights
        end
      end
    end
  end

  def self.get_cross_channel_patterns(start_date = 30.days.ago, end_date = Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:patterns:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          touchpoints = JourneyTouchpoint.where(occurred_at: start_date..end_date)
                                       .includes(:cross_channel_journey, :sales_channel)

          patterns = {
            channel_sequences: analyze_channel_sequences(touchpoints),
            popular_paths: identify_popular_paths(touchpoints),
            channel_transitions: calculate_channel_transitions(touchpoints),
            time_between_channels: calculate_time_between_channels(touchpoints),
            multi_channel_attribution: calculate_multi_channel_attribution(touchpoints)
          }

          EventPublisher.publish('journey_analytics.cross_channel_patterns_analyzed', {
            start_date: start_date,
            end_date: end_date,
            total_touchpoints: touchpoints.count,
            unique_journeys: touchpoints.distinct.count(:cross_channel_journey_id),
            patterns_identified: patterns.keys.count,
            analyzed_at: Time.current
          })

          patterns
        end
      end
    end
  end

  def self.get_user_journey_insights(user_id, start_date = 30.days.ago, end_date = Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:user_insights:#{user_id}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          journeys = CrossChannelJourney.where(user_id: user_id)
          touchpoints = JourneyTouchpoint.where(cross_channel_journey_id: journeys.pluck(:id))
                                        .where(occurred_at: start_date..end_date)
                                        .includes(:sales_channel)

          insights = {
            total_journeys: journeys.count,
            total_touchpoints: touchpoints.count,
            preferred_channels: touchpoints.group('sales_channels.channel_type').count,
            average_journey_length: touchpoints.count / journeys.count.to_f,
            journey_completion_rate: calculate_completion_rate(journeys),
            channel_loyalty_score: calculate_channel_loyalty(touchpoints),
            peak_activity_periods: touchpoints.group_by_hour_of_day(:occurred_at).count
          }

          EventPublisher.publish('journey_analytics.user_insights_generated', {
            user_id: user_id,
            start_date: start_date,
            end_date: end_date,
            total_journeys: insights[:total_journeys],
            total_touchpoints: insights[:total_touchpoints],
            preferred_channels_count: insights[:preferred_channels].keys.count,
            generated_at: Time.current
          })

          insights
        end
      end
    end
  end

  def self.predict_next_best_channel(journey_id)
    cache_key = "#{CACHE_KEY_PREFIX}:next_channel:#{journey_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(journey_id)
          patterns = get_cross_channel_patterns

          current_channels = touchpoints.map { |t| t.sales_channel.channel_type }
          next_channel = predict_next_channel_from_patterns(current_channels, patterns)

          prediction = {
            recommended_channel: next_channel,
            confidence_score: calculate_prediction_confidence(current_channels, next_channel),
            reasoning: generate_prediction_reasoning(current_channels, next_channel),
            alternative_channels: suggest_alternative_channels(current_channels, patterns)
          }

          EventPublisher.publish('journey_analytics.next_channel_predicted', {
            journey_id: journey_id,
            recommended_channel: prediction[:recommended_channel],
            confidence_score: prediction[:confidence_score],
            predicted_at: Time.current
          })

          prediction
        end
      end
    end
  end

  private

  def self.calculate_journey_duration(touchpoints)
    return 0 if touchpoints.empty?

    start_time = touchpoints.min_by(&:occurred_at).occurred_at
    end_time = touchpoints.max_by(&:occurred_at).occurred_at

    end_time - start_time
  end

  def self.build_conversion_funnel(touchpoints)
    actions = touchpoints.map(&:action)
    stages = ['awareness', 'consideration', 'decision', 'loyalty']

    funnel = {}
    stages.each do |stage|
      stage_actions = case stage
                     when 'awareness'
                       ['product_view', 'category_browse', 'search']
                     when 'consideration'
                       ['add_to_cart', 'wishlist_add', 'product_comparison']
                     when 'decision'
                       ['checkout_start', 'purchase', 'payment']
                     when 'loyalty'
                       ['review', 'repeat_purchase', 'referral']
                     end

      funnel[stage] = actions.count { |action| stage_actions.include?(action) }
    end

    funnel
  end

  def self.calculate_channel_effectiveness(touchpoints)
    effectiveness = {}

    touchpoints.group_by { |t| t.sales_channel.channel_type }.each do |channel_type, channel_touchpoints|
      effectiveness[channel_type] = {
        touchpoint_count: channel_touchpoints.count,
        engagement_score: channel_touchpoints.sum { |t| calculate_engagement_score(t) },
        conversion_rate: calculate_channel_conversion_rate(channel_touchpoints),
        average_time_to_conversion: calculate_time_to_conversion(channel_touchpoints)
      }
    end

    effectiveness
  end

  def self.calculate_engagement_score(touchpoints)
    touchpoints.sum { |t| calculate_engagement_score(t) }
  end

  def self.identify_drop_off_points(touchpoints)
    # Analyze where users tend to drop off in the journey
    sorted_touchpoints = touchpoints.sort_by(&:occurred_at)

    drop_offs = []
    sorted_touchpoints.each_cons(2) do |current, next_touchpoint|
      time_gap = next_touchpoint.occurred_at - current.occurred_at
      if time_gap > 24.hours
        drop_offs << {
          from_channel: current.sales_channel.channel_type,
          to_channel: next_touchpoint.sales_channel.channel_type,
          time_gap: time_gap,
          stage: determine_journey_stage(current)
        }
      end
    end

    drop_offs
  end

  def self.determine_optimal_path(touchpoints)
    # Determine the most effective sequence of channels
    channel_sequence = touchpoints.sort_by(&:occurred_at).map { |t| t.sales_channel.channel_type }

    {
      sequence: channel_sequence,
      effectiveness_score: calculate_sequence_effectiveness(channel_sequence),
      recommended: channel_sequence == channel_sequence.sort_by { |ch| channel_effectiveness_score(ch) }
    }
  end

  def self.analyze_channel_sequences(touchpoints)
    sequences = {}

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      sorted = journey_touchpoints.sort_by(&:occurred_at)
      sequence = sorted.map { |t| t.sales_channel.channel_type }

      sequence_key = sequence.join(' -> ')
      sequences[sequence_key] ||= 0
      sequences[sequence_key] += 1
    end

    sequences.sort_by { |_, count| -count }.first(10).to_h
  end

  def self.identify_popular_paths(touchpoints)
    # Identify most common channel transition patterns
    transitions = {}

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      sorted = journey_touchpoints.sort_by(&:occurred_at)
      sorted.each_cons(2) do |current, next_touchpoint|
        transition = "#{current.sales_channel.channel_type} -> #{next_touchpoint.sales_channel.channel_type}"
        transitions[transition] ||= 0
        transitions[transition] += 1
      end
    end

    transitions.sort_by { |_, count| -count }.first(10).to_h
  end

  def self.calculate_channel_transitions(touchpoints)
    transitions = Hash.new { |h, k| h[k] = Hash.new(0) }

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      sorted = journey_touchpoints.sort_by(&:occurred_at)
      sorted.each_cons(2) do |current, next_touchpoint|
        from_channel = current.sales_channel.channel_type
        to_channel = next_touchpoint.sales_channel.channel_type
        transitions[from_channel][to_channel] += 1
      end
    end

    transitions
  end

  def self.calculate_time_between_channels(touchpoints)
    times = []

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      sorted = journey_touchpoints.sort_by(&:occurred_at)
      sorted.each_cons(2) do |current, next_touchpoint|
        times << next_touchpoint.occurred_at - current.occurred_at
      end
    end

    {
      average: times.any? ? times.sum / times.count : 0,
      median: times.any? ? times.sort[times.count / 2] : 0,
      min: times.min || 0,
      max: times.max || 0
    }
  end

  def self.calculate_multi_channel_attribution(touchpoints)
    attribution = {}

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      journey = journey_touchpoints.first.cross_channel_journey

      if journey.completed?
        channel_weights = {}
        total_weight = 0

        journey_touchpoints.each do |touchpoint|
          weight = calculate_touchpoint_weight(touchpoint, journey_touchpoints)
          channel_weights[touchpoint.sales_channel.channel_type] ||= 0
          channel_weights[touchpoint.sales_channel.channel_type] += weight
          total_weight += weight
        end

        # Normalize weights
        channel_weights.each do |channel, weight|
          channel_weights[channel] = weight / total_weight
        end

        attribution[journey_id] = channel_weights
      end
    end

    attribution
  end

  def self.analyze_engagement_patterns(touchpoints)
    patterns = {
      session_frequency: calculate_session_frequency(touchpoints),
      time_of_day_preferences: touchpoints.group_by_hour_of_day(:occurred_at).count,
      day_of_week_preferences: touchpoints.group_by_day_of_week(:occurred_at).count,
      session_duration: calculate_session_duration(touchpoints)
    }

    patterns
  end

  def self.measure_conversion_impact(touchpoints)
    # Measure how touchpoints contribute to conversion
    journey_ids = touchpoints.distinct.pluck(:cross_channel_journey_id)
    journeys = CrossChannelJourney.where(id: journey_ids)

    converted_journeys = journeys.where(status: 'completed').count
    total_journeys = journeys.count

    {
      conversion_rate: total_journeys > 0 ? (converted_journeys.to_f / total_journeys) * 100 : 0,
      touchpoints_to_conversion: touchpoints.count / converted_journeys.to_f,
      channel_conversion_impact: calculate_channel_conversion_impact(touchpoints, journeys)
    }
  end

  def self.calculate_channel_stickiness(touchpoints)
    # Calculate how "sticky" each channel is (repeat usage)
    channel_usage = touchpoints.group_by { |t| t.sales_channel.channel_type }

    stickiness = {}
    channel_usage.each do |channel_type, channel_touchpoints|
      journey_ids = channel_touchpoints.map(&:cross_channel_journey_id).uniq
      total_touchpoints = channel_touchpoints.count
      unique_journeys = journey_ids.count

      stickiness[channel_type] = {
        total_touchpoints: total_touchpoints,
        unique_journeys: unique_journeys,
        stickiness_score: unique_journeys > 0 ? total_touchpoints / unique_journeys.to_f : 0,
        return_rate: calculate_return_rate(channel_touchpoints, journey_ids)
      }
    end

    stickiness
  end

  def self.calculate_completion_rate(journeys)
    completed = journeys.where(status: 'completed').count
    total = journeys.count

    total > 0 ? (completed.to_f / total) * 100 : 0
  end

  def self.calculate_channel_loyalty(touchpoints)
    channel_usage = touchpoints.group_by { |t| t.sales_channel.channel_type }

    loyalty = {}
    channel_usage.each do |channel_type, channel_touchpoints|
      journey_ids = channel_touchpoints.map(&:cross_channel_journey_id).uniq
      max_usage = channel_touchpoints.group_by(&:cross_channel_journey_id).values.map(&:count).max || 0

      loyalty[channel_type] = {
        usage_frequency: channel_touchpoints.count / journey_ids.count.to_f,
        max_usage_per_journey: max_usage,
        loyalty_score: max_usage > 1 ? (max_usage - 1) * 20 : 0
      }
    end

    loyalty
  end

  def self.predict_next_channel_from_patterns(current_channels, patterns)
    # Simple prediction based on common transitions
    transitions = patterns[:channel_transitions]

    next_channel_scores = {}
    current_channels.each do |channel|
      if transitions[channel]
        transitions[channel].each do |next_ch, count|
          next_channel_scores[next_ch] ||= 0
          next_channel_scores[next_ch] += count
        end
      end
    end

    next_channel_scores.max_by { |_, score| score }&.first || 'web'
  end

  def self.calculate_prediction_confidence(current_channels, next_channel)
    # Calculate confidence based on historical patterns
    75 # Simplified for now
  end

  def self.generate_prediction_reasoning(current_channels, next_channel)
    "Based on historical channel transition patterns, #{next_channel} is the most likely next channel after #{current_channels.join(', ')}"
  end

  def self.suggest_alternative_channels(current_channels, patterns)
    transitions = patterns[:channel_transitions]

    alternatives = []
    current_channels.each do |channel|
      if transitions[channel]
        transitions[channel].each do |next_ch, count|
          alternatives << { channel: next_ch, probability: count }
        end
      end
    end

    alternatives.group_by { |alt| alt[:channel] }
               .map { |channel, alts| { channel: channel, probability: alts.sum { |a| a[:probability] } } }
               .sort_by { |alt| -alt[:probability] }
               .first(3)
  end

  def self.calculate_touchpoint_weight(touchpoint, all_touchpoints)
    # Weight touchpoints based on their position and type
    position_weight = 1.0 / (all_touchpoints.index(touchpoint) + 1)
    action_weight = case touchpoint.action
                   when 'purchase'
                     1.0
                   when 'checkout_start'
                     0.8
                   when 'add_to_cart'
                     0.6
                   else
                     0.3
                   end

    position_weight * action_weight
  end

  def self.calculate_session_frequency(touchpoints)
    # Group touchpoints into sessions (30 minutes apart)
    sessions = []
    current_session = []

    sorted_touchpoints = touchpoints.sort_by(&:occurred_at)

    sorted_touchpoints.each do |touchpoint|
      if current_session.empty? || (touchpoint.occurred_at - current_session.last.occurred_at) <= 30.minutes
        current_session << touchpoint
      else
        sessions << current_session
        current_session = [touchpoint]
      end
    end

    sessions << current_session unless current_session.empty?

    sessions.count
  end

  def self.calculate_session_duration(touchpoints)
    # Calculate average session duration
    sessions = group_into_sessions(touchpoints)

    durations = sessions.map do |session|
      session.last.occurred_at - session.first.occurred_at
    end

    durations.any? ? durations.sum / durations.count : 0
  end

  def self.group_into_sessions(touchpoints)
    sessions = []
    current_session = []

    sorted_touchpoints = touchpoints.sort_by(&:occurred_at)

    sorted_touchpoints.each do |touchpoint|
      if current_session.empty? || (touchpoint.occurred_at - current_session.last.occurred_at) <= 30.minutes
        current_session << touchpoint
      else
        sessions << current_session
        current_session = [touchpoint]
      end
    end

    sessions << current_session unless current_session.empty?

    sessions
  end

  def self.calculate_channel_conversion_impact(touchpoints, journeys)
    impact = {}

    touchpoints.group_by { |t| t.sales_channel.channel_type }.each do |channel_type, channel_touchpoints|
      channel_journey_ids = channel_touchpoints.map(&:cross_channel_journey_id).uniq
      channel_journeys = journeys.where(id: channel_journey_ids)

      converted = channel_journeys.where(status: 'completed').count
      total = channel_journeys.count

      impact[channel_type] = {
        conversion_rate: total > 0 ? (converted.to_f / total) * 100 : 0,
        touchpoint_count: channel_touchpoints.count,
        journeys_affected: total
      }
    end

    impact
  end

  def self.calculate_return_rate(touchpoints, journey_ids)
    # Calculate how often users return to this channel
    channel_touchpoints = touchpoints.group_by(&:cross_channel_journey_id)

    return_visits = 0
    channel_touchpoints.each do |journey_id, journey_touchpoints|
      return_visits += 1 if journey_touchpoints.count > 1
    end

    journey_ids.count > 0 ? (return_visits.to_f / journey_ids.count) * 100 : 0
  end

  def self.channel_effectiveness_score(channel_type)
    # Simplified effectiveness scoring
    scores = {
      'web' => 80,
      'mobile_app' => 90,
      'marketplace' => 70,
      'social_media' => 60,
      'email' => 85,
      'chat' => 75
    }

    scores[channel_type.to_s] || 50
  end

  def self.calculate_sequence_effectiveness(sequence)
    # Calculate effectiveness of a channel sequence
    score = 0
    sequence.each_with_index do |channel, index|
      channel_score = channel_effectiveness_score(channel)
      position_multiplier = 1.0 / (index + 1) # Earlier channels get higher weight
      score += channel_score * position_multiplier
    end

    score
  end

  def self.clear_analytics_cache(journey_id, channel_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:performance:#{journey_id}",
      "#{CACHE_KEY_PREFIX}:insights:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:patterns",
      "#{CACHE_KEY_PREFIX}:user_insights",
      "#{CACHE_KEY_PREFIX}:next_channel:#{journey_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end</content>
<content lines="1-400">
class JourneyAnalyticsService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'journey_analytics'
  CACHE_TTL = 15.minutes

  def self.analyze_journey_performance(journey_id)
    cache_key = "#{CACHE_KEY_PREFIX}:performance:#{journey_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          journey = CrossChannelJourney.find(journey_id)
          touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(journey_id)

          analysis = {
            total_touchpoints: touchpoints.count,
            channels_used: touchpoints.map { |t| t.sales_channel.channel_type }.uniq,
            journey_duration: calculate_journey_duration(touchpoints),
            conversion_funnel: build_conversion_funnel(touchpoints),
            channel_effectiveness: calculate_channel_effectiveness(touchpoints),
            engagement_score: calculate_engagement_score(touchpoints),
            drop_off_points: identify_drop_off_points(touchpoints),
            optimal_path: determine_optimal_path(touchpoints)
          }

          EventPublisher.publish('journey_analytics.performance_analyzed', {
            journey_id: journey_id,
            user_id: journey.user_id,
            total_touchpoints: analysis[:total_touchpoints],
            channels_used: analysis[:channels_used].count,
            journey_duration: analysis[:journey_duration],
            engagement_score: analysis[:engagement_score],
            analyzed_at: Time.current
          })

          analysis
        end
      end
    end
  end

  def self.get_channel_insights(channel_id, start_date = 30.days.ago, end_date = Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:insights:#{channel_id}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_channel(channel_id)
                                        .where(occurred_at: start_date..end_date)

          insights = {
            touchpoint_volume: touchpoints.count,
            unique_journeys: touchpoints.distinct.count(:cross_channel_journey_id),
            action_distribution: touchpoints.group(:action).count,
            peak_activity_hours: touchpoints.group_by_hour_of_day(:occurred_at).count,
            user_engagement_patterns: analyze_engagement_patterns(touchpoints),
            conversion_impact: measure_conversion_impact(touchpoints),
            channel_stickiness: calculate_channel_stickiness(touchpoints)
          }

          EventPublisher.publish('journey_analytics.channel_insights_generated', {
            channel_id: channel_id,
            start_date: start_date,
            end_date: end_date,
            touchpoint_volume: insights[:touchpoint_volume],
            unique_journeys: insights[:unique_journeys],
            generated_at: Time.current
          })

          insights
        end
      end
    end
  end

  def self.get_cross_channel_patterns(start_date = 30.days.ago, end_date = Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:patterns:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          touchpoints = JourneyTouchpoint.where(occurred_at: start_date..end_date)
                                       .includes(:cross_channel_journey, :sales_channel)

          patterns = {
            channel_sequences: analyze_channel_sequences(touchpoints),
            popular_paths: identify_popular_paths(touchpoints),
            channel_transitions: calculate_channel_transitions(touchpoints),
            time_between_channels: calculate_time_between_channels(touchpoints),
            multi_channel_attribution: calculate_multi_channel_attribution(touchpoints)
          }

          EventPublisher.publish('journey_analytics.cross_channel_patterns_analyzed', {
            start_date: start_date,
            end_date: end_date,
            total_touchpoints: touchpoints.count,
            unique_journeys: touchpoints.distinct.count(:cross_channel_journey_id),
            patterns_identified: patterns.keys.count,
            analyzed_at: Time.current
          })

          patterns
        end
      end
    end
  end

  def self.get_user_journey_insights(user_id, start_date = 30.days.ago, end_date = Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:user_insights:#{user_id}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          journeys = CrossChannelJourney.where(user_id: user_id)
          touchpoints = JourneyTouchpoint.where(cross_channel_journey_id: journeys.pluck(:id))
                                        .where(occurred_at: start_date..end_date)
                                        .includes(:sales_channel)

          insights = {
            total_journeys: journeys.count,
            total_touchpoints: touchpoints.count,
            preferred_channels: touchpoints.group('sales_channels.channel_type').count,
            average_journey_length: touchpoints.count / journeys.count.to_f,
            journey_completion_rate: calculate_completion_rate(journeys),
            channel_loyalty_score: calculate_channel_loyalty(touchpoints),
            peak_activity_periods: touchpoints.group_by_hour_of_day(:occurred_at).count
          }

          EventPublisher.publish('journey_analytics.user_insights_generated', {
            user_id: user_id,
            start_date: start_date,
            end_date: end_date,
            total_journeys: insights[:total_journeys],
            total_touchpoints: insights[:total_touchpoints],
            preferred_channels_count: insights[:preferred_channels].keys.count,
            generated_at: Time.current
          })

          insights
        end
      end
    end
  end

  def self.predict_next_best_channel(journey_id)
    cache_key = "#{CACHE_KEY_PREFIX}:next_channel:#{journey_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_analytics') do
        with_retry do
          touchpoints = JourneyTouchpointManagementService.get_touchpoints_for_journey(journey_id)
          patterns = get_cross_channel_patterns

          current_channels = touchpoints.map { |t| t.sales_channel.channel_type }
          next_channel = predict_next_channel_from_patterns(current_channels, patterns)

          prediction = {
            recommended_channel: next_channel,
            confidence_score: calculate_prediction_confidence(current_channels, next_channel),
            reasoning: generate_prediction_reasoning(current_channels, next_channel),
            alternative_channels: suggest_alternative_channels(current_channels, patterns)
          }

          EventPublisher.publish('journey_analytics.next_channel_predicted', {
            journey_id: journey_id,
            recommended_channel: prediction[:recommended_channel],
            confidence_score: prediction[:confidence_score],
            predicted_at: Time.current
          })

          prediction
        end
      end
    end
  end

  private

  def self.calculate_journey_duration(touchpoints)
    return 0 if touchpoints.empty?

    start_time = touchpoints.min_by(&:occurred_at).occurred_at
    end_time = touchpoints.max_by(&:occurred_at).occurred_at

    end_time - start_time
  end

  def self.build_conversion_funnel(touchpoints)
    actions = touchpoints.map(&:action)
    stages = ['awareness', 'consideration', 'decision', 'loyalty']

    funnel = {}
    stages.each do |stage|
      stage_actions = case stage
                     when 'awareness'
                       ['product_view', 'category_browse', 'search']
                     when 'consideration'
                       ['add_to_cart', 'wishlist_add', 'product_comparison']
                     when 'decision'
                       ['checkout_start', 'purchase', 'payment']
                     when 'loyalty'
                       ['review', 'repeat_purchase', 'referral']
                     end

      funnel[stage] = actions.count { |action| stage_actions.include?(action) }
    end

    funnel
  end

  def self.calculate_channel_effectiveness(touchpoints)
    effectiveness = {}

    touchpoints.group_by { |t| t.sales_channel.channel_type }.each do |channel_type, channel_touchpoints|
      effectiveness[channel_type] = {
        touchpoint_count: channel_touchpoints.count,
        engagement_score: channel_touchpoints.sum { |t| calculate_engagement_score(t) },
        conversion_rate: calculate_channel_conversion_rate(channel_touchpoints),
        average_time_to_conversion: calculate_time_to_conversion(channel_touchpoints)
      }
    end

    effectiveness
  end

  def self.calculate_engagement_score(touchpoints)
    touchpoints.sum { |t| calculate_engagement_score(t) }
  end

  def self.identify_drop_off_points(touchpoints)
    # Analyze where users tend to drop off in the journey
    sorted_touchpoints = touchpoints.sort_by(&:occurred_at)

    drop_offs = []
    sorted_touchpoints.each_cons(2) do |current, next_touchpoint|
      time_gap = next_touchpoint.occurred_at - current.occurred_at
      if time_gap > 24.hours
        drop_offs << {
          from_channel: current.sales_channel.channel_type,
          to_channel: next_touchpoint.sales_channel.channel_type,
          time_gap: time_gap,
          stage: determine_journey_stage(current)
        }
      end
    end

    drop_offs
  end

  def self.determine_optimal_path(touchpoints)
    # Determine the most effective sequence of channels
    channel_sequence = touchpoints.sort_by(&:occurred_at).map { |t| t.sales_channel.channel_type }

    {
      sequence: channel_sequence,
      effectiveness_score: calculate_sequence_effectiveness(channel_sequence),
      recommended: channel_sequence == channel_sequence.sort_by { |ch| channel_effectiveness_score(ch) }
    }
  end

  def self.analyze_channel_sequences(touchpoints)
    sequences = {}

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      sorted = journey_touchpoints.sort_by(&:occurred_at)
      sequence = sorted.map { |t| t.sales_channel.channel_type }

      sequence_key = sequence.join(' -> ')
      sequences[sequence_key] ||= 0
      sequences[sequence_key] += 1
    end

    sequences.sort_by { |_, count| -count }.first(10).to_h
  end

  def self.identify_popular_paths(touchpoints)
    # Identify most common channel transition patterns
    transitions = {}

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      sorted = journey_touchpoints.sort_by(&:occurred_at)
      sorted.each_cons(2) do |current, next_touchpoint|
        transition = "#{current.sales_channel.channel_type} -> #{next_touchpoint.sales_channel.channel_type}"
        transitions[transition] ||= 0
        transitions[transition] += 1
      end
    end

    transitions.sort_by { |_, count| -count }.first(10).to_h
  end

  def self.calculate_channel_transitions(touchpoints)
    transitions = Hash.new { |h, k| h[k] = Hash.new(0) }

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      sorted = journey_touchpoints.sort_by(&:occurred_at)
      sorted.each_cons(2) do |current, next_touchpoint|
        from_channel = current.sales_channel.channel_type
        to_channel = next_touchpoint.sales_channel.channel_type
        transitions[from_channel][to_channel] += 1
      end
    end

    transitions
  end

  def self.calculate_time_between_channels(touchpoints)
    times = []

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      sorted = journey_touchpoints.sort_by(&:occurred_at)
      sorted.each_cons(2) do |current, next_touchpoint|
        times << next_touchpoint.occurred_at - current.occurred_at
      end
    end

    {
      average: times.any? ? times.sum / times.count : 0,
      median: times.any? ? times.sort[times.count / 2] : 0,
      min: times.min || 0,
      max: times.max || 0
    }
  end

  def self.calculate_multi_channel_attribution(touchpoints)
    attribution = {}

    touchpoints.group_by(&:cross_channel_journey_id).each do |journey_id, journey_touchpoints|
      journey = journey_touchpoints.first.cross_channel_journey

      if journey.completed?
        channel_weights = {}
        total_weight = 0

        journey_touchpoints.each do |touchpoint|
          weight = calculate_touchpoint_weight(touchpoint, journey_touchpoints)
          channel_weights[touchpoint.sales_channel.channel_type] ||= 0
          channel_weights[touchpoint.sales_channel.channel_type] += weight
          total_weight += weight
        end

        # Normalize weights
        channel_weights.each do |channel, weight|
          channel_weights[channel] = weight / total_weight
        end

        attribution[journey_id] = channel_weights
      end
    end

    attribution
  end

  def self.analyze_engagement_patterns(touchpoints)
    patterns = {
      session_frequency: calculate_session_frequency(touchpoints),
      time_of_day_preferences: touchpoints.group_by_hour_of_day(:occurred_at).count,
      day_of_week_preferences: touchpoints.group_by_day_of_week(:occurred_at).count,
      session_duration: calculate_session_duration(touchpoints)
    }

    patterns
  end

  def self.measure_conversion_impact(touchpoints)
    # Measure how touchpoints contribute to conversion
    journey_ids = touchpoints.distinct.pluck(:cross_channel_journey_id)
    journeys = CrossChannelJourney.where(id: journey_ids)

    converted_journeys = journeys.where(status: 'completed').count
    total_journeys = journeys.count

    {
      conversion_rate: total_journeys > 0 ? (converted_journeys.to_f / total_journeys) * 100 : 0,
      touchpoints_to_conversion: touchpoints.count / converted_journeys.to_f,
      channel_conversion_impact: calculate_channel_conversion_impact(touchpoints, journeys)
    }
  end

  def self.calculate_channel_stickiness(touchpoints)
    # Calculate how "sticky" each channel is (repeat usage)
    channel_usage = touchpoints.group_by { |t| t.sales_channel.channel_type }

    stickiness = {}
    channel_usage.each do |channel_type, channel_touchpoints|
      journey_ids = channel_touchpoints.map(&:cross_channel_journey_id).uniq
      total_touchpoints = channel_touchpoints.count
      unique_journeys = journey_ids.count

      stickiness[channel_type] = {
        total_touchpoints: total_touchpoints,
        unique_journeys: unique_journeys,
        stickiness_score: unique_journeys > 0 ? total_touchpoints / unique_journeys.to_f : 0,
        return_rate: calculate_return_rate(channel_touchpoints, journey_ids)
      }
    end

    stickiness
  end

  def self.calculate_completion_rate(journeys)
    completed = journeys.where(status: 'completed').count
    total = journeys.count

    total > 0 ? (completed.to_f / total) * 100 : 0
  end

  def self.calculate_channel_loyalty(touchpoints)
    channel_usage = touchpoints.group_by { |t| t.sales_channel.channel_type }

    loyalty = {}
    channel_usage.each do |channel_type, channel_touchpoints|
      journey_ids = channel_touchpoints.map(&:cross_channel_journey_id).uniq
      max_usage = channel_touchpoints.group_by(&:cross_channel_journey_id).values.map(&:count).max || 0

      loyalty[channel_type] = {
        usage_frequency: channel_touchpoints.count / journey_ids.count.to_f,
        max_usage_per_journey: max_usage,
        loyalty_score: max_usage > 1 ? (max_usage - 1) * 20 : 0
      }
    end

    loyalty
  end

  def self.predict_next_channel_from_patterns(current_channels, patterns)
    # Simple prediction based on common transitions
    transitions = patterns[:channel_transitions]

    next_channel_scores = {}
    current_channels.each do |channel|
      if transitions[channel]
        transitions[channel].each do |next_ch, count|
          next_channel_scores[next_ch] ||= 0
          next_channel_scores[next_ch] += count
        end
      end
    end

    next_channel_scores.max_by { |_, score| score }&.first || 'web'
  end

  def self.calculate_prediction_confidence(current_channels, next_channel)
    # Calculate confidence based on historical patterns
    75 # Simplified for now
  end

  def self.generate_prediction_reasoning(current_channels, next_channel)
    "Based on historical channel transition patterns, #{next_channel} is the most likely next channel after #{current_channels.join(', ')}"
  end

  def self.suggest_alternative_channels(current_channels, patterns)
    transitions = patterns[:channel_transitions]

    alternatives = []
    current_channels.each do |channel|
      if transitions[channel]
        transitions[channel].each do |next_ch, count|
          alternatives << { channel: next_ch, probability: count }
        end
      end
    end

    alternatives.group_by { |alt| alt[:channel] }
               .map { |channel, alts| { channel: channel, probability: alts.sum { |a| a[:probability] } } }
               .sort_by { |alt| -alt[:probability] }
               .first(3)
  end

  def self.calculate_touchpoint_weight(touchpoint, all_touchpoints)
    # Weight touchpoints based on their position and type
    position_weight = 1.0 / (all_touchpoints.index(touchpoint) + 1)
    action_weight = case touchpoint.action
                   when 'purchase'
                     1.0
                   when 'checkout_start'
                     0.8
                   when 'add_to_cart'
                     0.6
                   else
                     0.3
                   end

    position_weight * action_weight
  end

  def self.calculate_session_frequency(touchpoints)
    # Group touchpoints into sessions (30 minutes apart)
    sessions = []
    current_session = []

    sorted_touchpoints = touchpoints.sort_by(&:occurred_at)

    sorted_touchpoints.each do |touchpoint|
      if current_session.empty? || (touchpoint.occurred_at - current_session.last.occurred_at) <= 30.minutes
        current_session << touchpoint
      else
        sessions << current_session
        current_session = [touchpoint]
      end
    end

    sessions << current_session unless current_session.empty?

    sessions.count
  end

  def self.calculate_session_duration(touchpoints)
    # Calculate average session duration
    sessions = group_into_sessions(touchpoints)

    durations = sessions.map do |session|
      session.last.occurred_at - session.first.occurred_at
    end

    durations.any? ? durations.sum / durations.count : 0
  end

  def self.group_into_sessions(touchpoints)
    sessions = []
    current_session = []

    sorted_touchpoints = touchpoints.sort_by(&:occurred_at)

    sorted_touchpoints.each do |touchpoint|
      if current_session.empty? || (touchpoint.occurred_at - current_session.last.occurred_at) <= 30.minutes
        current_session << touchpoint
      else
        sessions << current_session
        current_session = [touchpoint]
      end
    end

    sessions << current_session unless current_session.empty?

    sessions
  end

  def self.calculate_channel_conversion_impact(touchpoints, journeys)
    impact = {}

    touchpoints.group_by { |t| t.sales_channel.channel_type }.each do |channel_type, channel_touchpoints|
      channel_journey_ids = channel_touchpoints.map(&:cross_channel_journey_id).uniq
      channel_journeys = journeys.where(id: channel_journey_ids)

      converted = channel_journeys.where(status: 'completed').count
      total = channel_journeys.count

      impact[channel_type] = {
        conversion_rate: total > 0 ? (converted.to_f / total) * 100 : 0,
        touchpoint_count: channel_touchpoints.count,
        journeys_affected: total
      }
    end

    impact
  end

  def self.calculate_return_rate(touchpoints, journey_ids)
    # Calculate how often users return to this channel
    channel_touchpoints = touchpoints.group_by(&:cross_channel_journey_id)

    return_visits = 0
    channel_touchpoints.each do |journey_id, journey_touchpoints|
      return_visits += 1 if journey_touchpoints.count > 1
    end

    journey_ids.count > 0 ? (return_visits.to_f / journey_ids.count) * 100 : 0
  end

  def self.channel_effectiveness_score(channel_type)
    # Simplified effectiveness scoring
    scores = {
      'web' => 80,
      'mobile_app' => 90,
      'marketplace' => 70,
      'social_media' => 60,
      'email' => 85,
      'chat' => 75
    }

    scores[channel_type.to_s] || 50
  end

  def self.calculate_sequence_effectiveness(sequence)
    # Calculate effectiveness of a channel sequence
    score = 0
    sequence.each_with_index do |channel, index|
      channel_score = channel_effectiveness_score(channel)
      position_multiplier = 1.0 / (index + 1) # Earlier channels get higher weight
      score += channel_score * position_multiplier
    end

    score
  end

  def self.clear_analytics_cache(journey_id, channel_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:performance:#{journey_id}",
      "#{CACHE_KEY_PREFIX}:insights:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:patterns",
      "#{CACHE_KEY_PREFIX}:user_insights",
      "#{CACHE_KEY_PREFIX}:next_channel:#{journey_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end