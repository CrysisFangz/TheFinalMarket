class OmnichannelCustomerProfileService
  attr_reader :customer

  def initialize(customer)
    @customer = customer
  end

  def unified_profile
    Rails.logger.debug("Generating unified profile for customer ID: #{customer.id}")

    begin
      profile = {
        user_id: customer.user.id,
        total_orders: total_orders_count,
        total_spent: total_lifetime_value,
        favorite_channel: favorite_channel,
        channels_used: channels_used,
        last_interaction: customer.last_interaction_at,
        customer_segment: customer_segment,
        preferences: unified_preferences,
        journey_summary: journey_summary
      }

      Rails.logger.info("Successfully generated unified profile for customer ID: #{customer.id}")
      profile
    rescue => e
      Rails.logger.error("Failed to generate unified profile for customer ID: #{customer.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  def favorite_channel
    Rails.logger.debug("Calculating favorite channel for customer ID: #{customer.id}")

    begin
      favorite = customer.channel_interactions
        .group(:sales_channel_id)
        .count
        .max_by { |_, count| count }
        &.first
        &.then { |id| SalesChannel.find(id).name }

      Rails.logger.debug("Favorite channel for customer ID: #{customer.id} is: #{favorite}")
      favorite
    rescue => e
      Rails.logger.error("Failed to calculate favorite channel for customer ID: #{customer.id}. Error: #{e.message}")
      nil
    end
  end

  def channels_used
    Rails.logger.debug("Getting channels used for customer ID: #{customer.id}")

    begin
      channels = customer.channel_interactions
        .joins(:sales_channel)
        .distinct
        .pluck('sales_channels.name')

      Rails.logger.debug("Channels used for customer ID: #{customer.id}: #{channels}")
      channels
    rescue => e
      Rails.logger.error("Failed to get channels used for customer ID: #{customer.id}. Error: #{e.message}")
      []
    end
  end

  def total_orders_count
    Rails.logger.debug("Calculating total orders count for customer ID: #{customer.id}")

    begin
      count = Order.where(user: customer.user).count
      Rails.logger.debug("Total orders count for customer ID: #{customer.id}: #{count}")
      count
    rescue => e
      Rails.logger.error("Failed to calculate total orders count for customer ID: #{customer.id}. Error: #{e.message}")
      0
    end
  end

  def total_lifetime_value
    Rails.logger.debug("Calculating total lifetime value for customer ID: #{customer.id}")

    begin
      value = Order.where(user: customer.user, status: 'completed').sum(:total)
      Rails.logger.debug("Total lifetime value for customer ID: #{customer.id}: #{value}")
      value
    rescue => e
      Rails.logger.error("Failed to calculate total lifetime value for customer ID: #{customer.id}. Error: #{e.message}")
      0
    end
  end

  def customer_segment
    Rails.logger.debug("Determining customer segment for customer ID: #{customer.id}")

    begin
      ltv = total_lifetime_value
      orders = total_orders_count

      segment = if ltv > 10000 && orders > 20
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

      Rails.logger.debug("Customer segment for customer ID: #{customer.id}: #{segment}")
      segment
    rescue => e
      Rails.logger.error("Failed to determine customer segment for customer ID: #{customer.id}. Error: #{e.message}")
      'unknown'
    end
  end

  def unified_preferences
    Rails.logger.debug("Generating unified preferences for customer ID: #{customer.id}")

    begin
      prefs = {}

      customer.channel_preferences.each do |cp|
        prefs[cp.sales_channel.name] = cp.preferences_data
      end

      # Merge and find common preferences
      preferences = {
        by_channel: prefs,
        common: find_common_preferences(prefs)
      }

      Rails.logger.debug("Generated unified preferences for customer ID: #{customer.id}")
      preferences
    rescue => e
      Rails.logger.error("Failed to generate unified preferences for customer ID: #{customer.id}. Error: #{e.message}")
      { by_channel: {}, common: {} }
    end
  end

  private

  def find_common_preferences(channel_prefs)
    Rails.logger.debug("Finding common preferences for customer ID: #{customer.id}")

    begin
      return {} if channel_prefs.empty?

      common = {}
      first_prefs = channel_prefs.values.first || {}

      first_prefs.each do |key, value|
        if channel_prefs.values.all? { |prefs| prefs[key] == value }
          common[key] = value
        end
      end

      Rails.logger.debug("Found common preferences for customer ID: #{customer.id}: #{common}")
      common
    rescue => e
      Rails.logger.error("Failed to find common preferences for customer ID: #{customer.id}. Error: #{e.message}")
      {}
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