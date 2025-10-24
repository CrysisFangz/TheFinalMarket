class SyncInventoryJob < ApplicationJob
  queue_as :default

  def perform(sales_channel_id)
    sales_channel = SalesChannel.find(sales_channel_id)
    service = SalesChannelInventoryService.new(sales_channel)
    service.send(:sync_products_inventory)
  end
end