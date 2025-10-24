# frozen_string_literal: true

class IndexProductJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find(product_id)
    product.__elasticsearch__.index_document
  rescue ActiveRecord::RecordNotFound
    # Handle if product is deleted
  rescue StandardError => e
    Rails.logger.error("Error indexing product: #{e.message}")
  end
end