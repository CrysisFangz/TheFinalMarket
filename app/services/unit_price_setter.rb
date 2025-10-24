# frozen_string_literal: true

# Service for setting the unit price of an order item, optimized for performance and resilience.
# Incorporates caching and error handling to prevent N+1 queries and ensure data integrity.
class UnitPriceSetter
  # Sets the unit price for an order item based on the associated item's price.
  # @param order_item [OrderItem] The order item to update.
  # @return [BigDecimal, nil] The set unit price or nil if failed.
  def self.set_unit_price(order_item)
    return unless order_item.item

    # Use Rails cache to avoid repeated database queries for item price.
    # Cache key based on item ID and updated_at for invalidation on changes.
    cache_key = "item_price_#{order_item.item.id}_#{order_item.item.updated_at.to_i}"

    unit_price = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      order_item.item.price
    end

    order_item.unit_price = unit_price if order_item.unit_price.nil?
    unit_price
  rescue ActiveRecord::RecordNotFound, NoMethodError => e
    # Handle cases where item is not found or price is inaccessible.
    Rails.logger.error("Failed to set unit price for OrderItem #{order_item.id}: #{e.message}")
    nil
  end
end