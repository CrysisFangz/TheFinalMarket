# frozen_string_literal: true

class GenerateThumbnailJob < ApplicationJob
  queue_as :default

  def perform(product_image_id)
    product_image = ProductImage.find(product_image_id)
    ProductImageService.generate_thumbnail(product_image)
  rescue ActiveRecord::RecordNotFound
    # Handle if product image is deleted
  rescue StandardError => e
    Rails.logger.error("Error generating thumbnail: #{e.message}")
  end
end