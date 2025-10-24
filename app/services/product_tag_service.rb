# frozen_string_literal: true

# Service for managing product tags with performance optimization and caching.
# Ensures efficient tag operations and maintains data consistency.
class ProductTagService
  # Updates product tags from a comma-separated string.
  # @param product [Product] The product to update tags for.
  # @param tag_names [String] Comma-separated tag names.
  def self.update_tags(product, tag_names)
    return unless tag_names.present?

    tags = tag_names.split(',').map(&:strip).map do |name|
      Tag.find_or_create_by(name: name)
    end

    product.tags = tags

    # Clear cache
    Rails.cache.delete("product:#{product.id}:tag_list")

    # Publish event
    EventPublisher.publish('product_tags_updated', {
      product_id: product.id,
      tag_count: tags.count,
      tag_names: tags.pluck(:name)
    })

    tags
  rescue StandardError => e
    Rails.logger.error("Failed to update tags for product #{product.id}: #{e.message}")
    raise
  end

  # Gets cached tag list for a product.
  # @param product [Product] The product.
  # @return [String] Comma-separated tag names.
  def self.get_tag_list(product)
    Rails.cache.fetch("product:#{product.id}:tag_list", expires_in: 1.hour) do
      product.tags.pluck(:name).join(', ')
    end
  end

  # Batch updates tags for multiple products.
  # @param products [Array<Product>] Products to update.
  # @param tags_data [Hash] Product ID => tag names mapping.
  def self.batch_update_tags(products, tags_data)
    products.each do |product|
      update_tags(product, tags_data[product.id]) if tags_data[product.id]
    end
  rescue StandardError => e
    Rails.logger.error("Batch tag update failed: #{e.message}")
    false
  end
end