class OmnichannelCustomerJourneyService
  attr_reader :customer

  def initialize(customer)
    @customer = customer
  end

  def track_interaction(channel, interaction_type, metadata = {})
    Rails.logger.info("Tracking interaction for customer ID: #{customer.id}, channel: #{channel.name}, type: #{interaction_type}")

    begin
      interaction = customer.channel_interactions.create!(
        sales_channel: channel,
        interaction_type: interaction_type,
        interaction_data: metadata,
        occurred_at: Time.current
      )

      customer.update!(last_interaction_at: Time.current)

      Rails.logger.info("Successfully tracked interaction ID: #{interaction.id} for customer ID: #{customer.id}")
      interaction
    rescue => e
      Rails.logger.error("Failed to track interaction for customer ID: #{customer.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  def start_journey(channel, intent)
    Rails.logger.info("Starting journey for customer ID: #{customer.id}, channel: #{channel.name}, intent: #{intent}")

    begin
      journey = customer.cross_channel_journeys.create!(
        sales_channel: channel,
        intent: intent,
        started_at: Time.current,
        touchpoint_count: 1,
        journey_data: { channels: [channel.name] }
      )

      Rails.logger.info("Successfully started journey ID: #{journey.id} for customer ID: #{customer.id}")
      journey
    rescue => e
      Rails.logger.error("Failed to start journey for customer ID: #{customer.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  def update_journey(journey, channel, touchpoint_data = {})
    Rails.logger.debug("Updating journey ID: #{journey.id} for customer ID: #{customer.id}")

    begin
      current_channels = journey.journey_data['channels'] || []
      updated_channels = current_channels | [channel.name]

      journey.update!(
        touchpoint_count: journey.touchpoint_count + 1,
        journey_data: journey.journey_data.merge(
          'channels' => updated_channels,
          'last_touchpoint' => {
            'channel' => channel.name,
            'timestamp' => Time.current,
            'data' => touchpoint_data
          }
        )
      )

      Rails.logger.debug("Successfully updated journey ID: #{journey.id}")
      journey
    rescue => e
      Rails.logger.error("Failed to update journey ID: #{journey.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  def complete_journey(journey, outcome_data = {})
    Rails.logger.info("Completing journey ID: #{journey.id} for customer ID: #{customer.id}")

    begin
      journey.update!(
        completed: true,
        completed_at: Time.current,
        journey_data: journey.journey_data.merge(
          'outcome' => outcome_data,
          'duration_hours' => ((Time.current - journey.started_at) / 3600.0).round(2)
        )
      )

      Rails.logger.info("Successfully completed journey ID: #{journey.id}")
      journey
    rescue => e
      Rails.logger.error("Failed to complete journey ID: #{journey.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  def journey_summary
    Rails.logger.debug("Generating journey summary for customer ID: #{customer.id}")

    begin
      journeys = customer.cross_channel_journeys.order(started_at: :desc).limit(10)

      summary = {
        total_journeys: customer.cross_channel_journeys.count,
        completed_journeys: customer.cross_channel_journeys.where(completed: true).count,
        average_touchpoints: customer.cross_channel_journeys.average(:touchpoint_count).to_f.round(2),
        average_duration: average_journey_duration,
        recent_journeys: journeys.map(&:summary)
      }

      Rails.logger.debug("Generated journey summary for customer ID: #{customer.id}")
      summary
    rescue => e
      Rails.logger.error("Failed to generate journey summary for customer ID: #{customer.id}. Error: #{e.message}")
      {
        total_journeys: 0,
        completed_journeys: 0,
        average_touchpoints: 0,
        average_duration: 0,
        recent_journeys: []
      }
    end
  end

  private

  def average_journey_duration
    Rails.logger.debug("Calculating average journey duration for customer ID: #{customer.id}")

    begin
      journeys = customer.cross_channel_journeys.where.not(completed_at: nil)
      return 0 if journeys.empty?

      total_duration = journeys.sum do |journey|
        (journey.completed_at - journey.started_at).to_i
      end

      duration = (total_duration / journeys.count / 3600.0).round(2) # in hours
      Rails.logger.debug("Average journey duration for customer ID: #{customer.id}: #{duration}")
      duration
    rescue => e
      Rails.logger.error("Failed to calculate average journey duration for customer ID: #{customer.id}. Error: #{e.message}")
      0
    end
  end
end