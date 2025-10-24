class SalesChannelInventoryService
  attr_reader :sales_channel

  def initialize(sales_channel)
    @sales_channel = sales_channel
  end

  def sync_inventory!
    Rails.logger.info("Starting inventory sync for SalesChannel ID: #{sales_channel.id}")
    SyncInventoryJob.perform_later(sales_channel.id)
    Rails.logger.info("Inventory sync job enqueued for SalesChannel ID: #{sales_channel.id}")
  rescue StandardError => e
    Rails.logger.error("Error syncing inventory for SalesChannel ID: #{sales_channel.id} - #{e.message}")
    raise
  end

  def available_products
    Rails.logger.debug("Fetching available products for SalesChannel ID: #{sales_channel.id}")
    sales_channel.channel_products.where(available: true).includes(:product)
  rescue StandardError => e
    Rails.logger.error("Error fetching available products for SalesChannel ID: #{sales_channel.id} - #{e.message}")
    []
  end
end

# Assuming a background job for async sync
class SyncInventoryJob < ApplicationJob
  queue_as :default

  def perform(sales_channel_id)
    sales_channel = SalesChannel.find(sales_channel_id)
    service = SalesChannelInventoryService.new(sales_channel)
    service.sync_products_inventory
  end
end

# Add this method to the service
class SalesChannelInventoryService
  private

  def sync_products_inventory
    sales_channel.products.find_each do |product|
      ChannelInventory.sync_for_product(product, sales_channel)
    rescue StandardError => e
      Rails.logger.error("Error syncing inventory for product ID: #{product.id} in SalesChannel ID: #{sales_channel.id} - #{e.message}")
      # Optionally, handle retries or dead-letter queue
    end
  end
end