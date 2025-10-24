class SalesChannelConfigurationService
  attr_reader :sales_channel

  def initialize(sales_channel)
    @sales_channel = sales_channel
  end

  def configuration
    Rails.logger.info("Fetching configuration for SalesChannel ID: #{sales_channel.id}")
    sales_channel.config_data || default_configuration
  rescue StandardError => e
    Rails.logger.error("Error fetching configuration for SalesChannel ID: #{sales_channel.id} - #{e.message}")
    default_configuration
  end

  def update_configuration(new_config)
    Rails.logger.info("Updating configuration for SalesChannel ID: #{sales_channel.id}")
    updated_config = configuration.merge(new_config)
    sales_channel.update!(config_data: updated_config)
    Rails.logger.info("Configuration updated successfully for SalesChannel ID: #{sales_channel.id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error updating configuration for SalesChannel ID: #{sales_channel.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error updating configuration for SalesChannel ID: #{sales_channel.id} - #{e.message}")
    raise
  end

  private

  def default_configuration
    {
      currency: 'USD',
      language: 'en',
      tax_included: false,
      shipping_enabled: true,
      payment_methods: ['credit_card', 'paypal'],
      fulfillment_method: 'standard'
    }
  end
end