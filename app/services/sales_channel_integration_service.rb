class SalesChannelIntegrationService
  attr_reader :sales_channel

  def initialize(sales_channel)
    @sales_channel = sales_channel
  end

  def integration_status
    Rails.logger.debug("Checking integration status for SalesChannel ID: #{sales_channel.id}")
    integration = sales_channel.channel_integrations.active.first

    status = if integration
      {
        connected: true,
        platform: integration.platform_name,
        last_sync: integration.last_sync_at,
        sync_status: integration.sync_status,
        errors: integration.error_count
      }
    else
      {
        connected: false,
        platform: nil,
        last_sync: nil,
        sync_status: 'not_configured',
        errors: 0
      }
    end
    Rails.logger.debug("Integration status retrieved for SalesChannel ID: #{sales_channel.id}")
    status
  rescue StandardError => e
    Rails.logger.error("Error checking integration status for SalesChannel ID: #{sales_channel.id} - #{e.message}")
    {
      connected: false,
      platform: nil,
      last_sync: nil,
      sync_status: 'error',
      errors: 0
    }
  end
end