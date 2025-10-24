# frozen_string_literal: true

# Service for generating thumbnails from product images.
# Optimized for performance with background processing and error handling.
class ThumbnailGenerationService
  THUMBNAIL_SIZE = [300, 300].freeze

  # Generates a thumbnail for a product image.
  # @param product_image [ProductImage] The product image.
  # @return [Boolean] True if generation was scheduled successfully.
  def self.generate_thumbnail(product_image)
    return false unless product_image.image.attached?

    # Schedule thumbnail generation in background
    GenerateThumbnailJob.perform_later(product_image.id)

    # Publish event
    EventPublisher.publish('thumbnail_generation_scheduled', {
      product_image_id: product_image.id,
      product_id: product_image.product_id
    })

    true
  rescue StandardError => e
    Rails.logger.error("Failed to schedule thumbnail generation for ProductImage #{product_image.id}: #{e.message}")
    false
  end

  # Processes thumbnail generation (called by background job).
  # @param product_image_id [Integer] The product image ID.
  # @return [Boolean] True if processed successfully.
  def self.process_thumbnail_generation(product_image_id)
    product_image = ProductImage.find(product_image_id)
    return false unless product_image.image.attached?

    product_image.image.variant(resize_to_limit: THUMBNAIL_SIZE).processed.tap do |thumbnail|
      product_image.thumbnail.attach(thumbnail)
    end

    # Publish event
    EventPublisher.publish('thumbnail_generated', {
      product_image_id: product_image.id,
      product_id: product_image.product_id
    })

    true
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("ProductImage #{product_image_id} not found for thumbnail generation")
    false
  rescue StandardError => e
    Rails.logger.error("Failed to generate thumbnail for ProductImage #{product_image_id}: #{e.message}")
    false
  end
end