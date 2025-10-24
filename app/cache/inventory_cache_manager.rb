# frozen_string_literal: true

module Cache
  class InventoryCacheManager
    def self.stock_status_key(inventory_id, version)
      "inventory:#{inventory_id}:status:#{version}"
    end

    def self.summary_key(inventory_id, version)
      "inventory:#{inventory_id}:summary:#{version}"
    end

    def self.health_key(inventory_id, version)
      "inventory:#{inventory_id}:health:#{version}"
    end

    def self.invalidate_related_caches(inventory_id, product_id, sales_channel_id, version)
      cache_patterns = [
        "inventory:#{inventory_id}:*",
        "product:#{product_id}:inventory:*",
        "channel:#{sales_channel_id}:inventory:*",
        "inventory:status:*"
      ]

      cache_patterns.each do |pattern|
        Rails.cache.delete_matched(pattern)
      end
    end

    def self.prewarm_critical_caches(inventory)
      Rails.cache.write(stock_status_key(inventory.id, inventory.version), inventory.stock_status, expires_in: 5.minutes)
      Rails.cache.write(summary_key(inventory.id, inventory.version), inventory.domain_entity.summary, expires_in: 10.minutes)
      # Add health if needed
    end

    def self.get_stock_status(inventory_id, version)
      Rails.cache.read(stock_status_key(inventory_id, version))
    end

    def self.set_stock_status(inventory_id, version, status)
      Rails.cache.write(stock_status_key(inventory_id, version), status, expires_in: 5.minutes)
    end
  end
end