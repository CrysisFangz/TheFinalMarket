class SalesChannelManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'sales_channel_management'
  CACHE_TTL = 15.minutes

  def self.enable_channel(channel)
    cache_key = "#{CACHE_KEY_PREFIX}:enable:#{channel.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_management') do
        with_retry do
          channel.update!(status: :active, enabled_at: Time.current)

          EventPublisher.publish('sales_channel.enabled', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            enabled_at: channel.enabled_at,
            previous_status: channel.status_previously_was
          })

          true
        end
      end
    end
  end

  def self.disable_channel(channel)
    cache_key = "#{CACHE_KEY_PREFIX}:disable:#{channel.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_management') do
        with_retry do
          channel.update!(status: :inactive, disabled_at: Time.current)

          EventPublisher.publish('sales_channel.disabled', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            disabled_at: channel.disabled_at,
            previous_status: channel.status_previously_was
          })

          true
        end
      end
    end
  end

  def self.update_channel_configuration(channel, new_config)
    cache_key = "#{CACHE_KEY_PREFIX}:config:#{channel.id}:#{new_config.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_management') do
        with_retry do
          config_service = SalesChannelConfigurationService.new(channel)
          result = config_service.update_configuration(new_config)

          EventPublisher.publish('sales_channel.configuration_updated', {
            channel_id: channel.id,
            channel_type: channel.channel_type,
            name: channel.name,
            config_changes: new_config,
            updated_at: Time.current
          })

          result
        end
      end
    end
  end

  def self.get_channel_configuration(channel)
    cache_key = "#{CACHE_KEY_PREFIX}:get_config:#{channel.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('sales_channel_management') do
        with_retry do
          config_service = SalesChannelConfigurationService.new(channel)
          config_service.configuration
        end
      end
    end
  end

  def self.get_active_channels
    cache_key = "#{CACHE_KEY_PREFIX}:active_channels"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      with_circuit_breaker('sales_channel_management') do
        with_retry do
          SalesChannel.active_channels.includes(:channel_products, :orders).to_a
        end
      end
    end
  end

  def self.get_channels_by_type(channel_type)
    cache_key = "#{CACHE_KEY_PREFIX}:channels_by_type:#{channel_type}"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      with_circuit_breaker('sales_channel_management') do
        with_retry do
          SalesChannel.where(channel_type: channel_type).includes(:channel_products, :orders).to_a
        end
      end
    end
  end

  def self.get_channel_health_status(channel)
    cache_key = "#{CACHE_KEY_PREFIX}:health:#{channel.id}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('sales_channel_management') do
        with_retry do
          analytics_service = SalesChannelAnalyticsService.new(channel)
          health_check = analytics_service.health_check

          {
            status: health_check[:status],
            response_time: health_check[:response_time],
            error_rate: health_check[:error_rate],
            uptime_percentage: health_check[:uptime_percentage],
            last_checked: Time.current
          }
        end
      end
    end
  end

  def self.clear_channel_cache(channel_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:enable:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:disable:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:config:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:get_config:#{channel_id}",
      "#{CACHE_KEY_PREFIX}:health:#{channel_id}",
      "sales_channel:#{channel_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end