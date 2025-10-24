# frozen_string_literal: true

class BulkSyncChannelProductsJob < ApplicationJob
  queue_as :default

  def perform(product_ids, sync_context = {})
    products = Product.where(id: product_ids).includes(:channel_products)

    results = products.flat_map do |product|
      product.channel_products.map do |channel_product|
        channel_product.sync_from_product!(sync_context)
      end
    end

    # Log results
    Rails.logger.info("Bulk sync completed: #{results.size} processed")
  rescue StandardError => e
    Rails.logger.error("Error in bulk sync: #{e.message}")
  end
end