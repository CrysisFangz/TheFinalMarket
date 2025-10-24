class JourneyTouchpointManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'journey_touchpoint_management'
  CACHE_TTL = 10.minutes

  def self.create_touchpoint(cross_channel_journey, sales_channel, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create:#{cross_channel_journey.id}:#{sales_channel.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_touchpoint_management') do
        with_retry do
          touchpoint = JourneyTouchpoint.new(
            cross_channel_journey: cross_channel_journey,
            sales_channel: sales_channel,
            occurred_at: Time.current,
            **attributes
          )

          if touchpoint.save
            EventPublisher.publish('journey_touchpoint.created', {
              touchpoint_id: touchpoint.id,
              journey_id: cross_channel_journey.id,
              channel_id: sales_channel.id,
              channel_type: sales_channel.channel_type,
              action: touchpoint.action,
              occurred_at: touchpoint.occurred_at,
              created_at: touchpoint.created_at
            })

            touchpoint
          else
            false
          end
        end
      end
    end
  end

  def self.record_touchpoint(journey, channel, action, touchpoint_data = {})
    cache_key = "#{CACHE_KEY_PREFIX}:record:#{journey.id}:#{channel.id}:#{action}:#{touchpoint_data.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_touchpoint_management') do
        with_retry do
          touchpoint = JourneyTouchpoint.create!(
            cross_channel_journey: journey,
            sales_channel: channel,
            action: action,
            touchpoint_data: touchpoint_data,
            occurred_at: Time.current
          )

          EventPublisher.publish('journey_touchpoint.recorded', {
            touchpoint_id: touchpoint.id,
            journey_id: journey.id,
            channel_id: channel.id,
            channel_type: channel.channel_type,
            action: action,
            touchpoint_data: touchpoint_data,
            recorded_at: Time.current
          })

          clear_touchpoint_cache(journey.id, channel.id)
          touchpoint
        end
      end
    end
  end

  def self.get_touchpoints_for_journey(journey_id)
    cache_key = "#{CACHE_KEY_PREFIX}:journey:#{journey_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_touchpoint_management') do
        with_retry do
          JourneyTouchpoint.where(cross_channel_journey_id: journey_id)
                          .includes(:sales_channel)
                          .order(occurred_at: :desc)
                          .to_a
        end
      end
    end
  end

  def self.get_touchpoints_for_channel(channel_id)
    cache_key = "#{CACHE_KEY_PREFIX}:channel:#{channel_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_touchpoint_management') do
        with_retry do
          JourneyTouchpoint.where(sales_channel_id: channel_id)
                          .includes(:cross_channel_journey)
                          .order(occurred_at: :desc)
                          .to_a
        end
      end
    end
  end

  def self.get_touchpoint_summary(touchpoint)
    cache_key = "#{CACHE_KEY_PREFIX}:summary:#{touchpoint.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_touchpoint_management') do
        with_retry do
          {
            channel: touchpoint.sales_channel.name,
            channel_type: touchpoint.sales_channel.channel_type,
            action: touchpoint.action,
            timestamp: touchpoint.occurred_at,
            data: touchpoint.touchpoint_data,
            journey_stage: determine_journey_stage(touchpoint),
            engagement_score: calculate_engagement_score(touchpoint)
          }
        end
      end
    end
  end

  def self.get_touchpoint_sequence(journey_id)
    cache_key = "#{CACHE_KEY_PREFIX}:sequence:#{journey_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_touchpoint_management') do
        with_retry do
          touchpoints = JourneyTouchpoint.where(cross_channel_journey_id: journey_id)
                                        .includes(:sales_channel)
                                        .order(occurred_at: :asc)
                                        .to_a

          sequence = touchpoints.map do |touchpoint|
            {
              id: touchpoint.id,
              channel: touchpoint.sales_channel.name,
              channel_type: touchpoint.sales_channel.channel_type,
              action: touchpoint.action,
              timestamp: touchpoint.occurred_at,
              data: touchpoint.touchpoint_data,
              time_from_start: touchpoint.occurred_at - touchpoints.first.occurred_at
            }
          end

          EventPublisher.publish('journey_touchpoint.sequence_retrieved', {
            journey_id: journey_id,
            touchpoints_count: sequence.count,
            time_span: sequence.last[:timestamp] - sequence.first[:timestamp],
            channels_used: sequence.map { |t| t[:channel_type] }.uniq,
            retrieved_at: Time.current
          })

          sequence
        end
      end
    end
  end

  def self.get_channel_performance(channel_id, start_date = 30.days.ago, end_date = Time.current)
    cache_key = "#{CACHE_KEY_PREFIX}:performance:#{channel_id}:#{start_date.to_i}:#{end_date.to_i}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('journey_touchpoint_management') do
        with_retry do
          touchpoints = JourneyTouchpoint.where(sales_channel_id: channel_id)
                                        .where(occurred_at: start_date..end_date)

          performance = {
            total_touchpoints: touchpoints.count,
            unique_journeys: touchpoints.distinct.count(:cross_channel_journey_id),
            actions_performed: touchpoints.group(:action).count,
            average_touchpoints_per_journey: touchpoints.count / touchpoints.distinct.count(:cross_channel_journey_id).to_f,
            peak_hours: touchpoints.group_by_hour_of_day(:occurred_at).count,
            conversion_rate: calculate_channel_conversion_rate(touchpoints)
          }

          EventPublisher.publish('journey_touchpoint.channel_performance_calculated', {
            channel_id: channel_id,
            start_date: start_date,
            end_date: end_date,
            total_touchpoints: performance[:total_touchpoints],
            unique_journeys: performance[:unique_journeys],
            calculated_at: Time.current
          })

          performance
        end
      end
    end
  end

  private

  def self.determine_journey_stage(touchpoint)
    case touchpoint.action
    when 'product_view', 'category_browse'
      'awareness'
    when 'add_to_cart', 'wishlist_add'
      'consideration'
    when 'purchase', 'checkout_start'
      'decision'
    when 'review', 'repeat_purchase'
      'loyalty'
    else
      'engagement'
    end
  end

  def self.calculate_engagement_score(touchpoint)
    base_score = 10

    # Higher score for more engaging actions
    engagement_weights = {
      'purchase' => 50,
      'review' => 30,
      'add_to_cart' => 20,
      'product_view' => 10,
      'category_browse' => 5
    }

    base_score + (engagement_weights[touchpoint.action.to_s] || 5)
  end

  def self.calculate_channel_conversion_rate(touchpoints)
    # Calculate conversion from touchpoint to purchase
    journey_ids = touchpoints.distinct.pluck(:cross_channel_journey_id)
    journeys = CrossChannelJourney.where(id: journey_ids)

    converted_journeys = journeys.where(status: 'completed').count
    total_journeys = journeys.count

    total_journeys > 0 ? (converted_journeys.to_f / total_journeys) * 100 : 0
  end

  def self.clear_touchpoint_cache(journey_id, channel_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:journey:#{journey_id}",
      "#{CACHE_KEY_PREFIX}:channel:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:sequence:#{journey_id}",
      "#{CACHE_KEY_PREFIX}:performance:#{channel_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end