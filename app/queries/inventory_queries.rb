# frozen_string_literal: true

module Queries
  class InventoryQueries
    def self.in_stock
      ChannelInventory.where('quantity > reserved_quantity').where('last_synced_at > ?', 1.hour.ago)
    end

    def self.out_of_stock
      ChannelInventory.where('quantity <= reserved_quantity OR quantity = 0').where('last_synced_at > ?', 1.hour.ago)
    end

    def self.low_stock(threshold = 10)
      ChannelInventory.where('quantity > 0 AND quantity <= reserved_quantity + ?', threshold).where('last_synced_at > ?', 1.hour.ago)
    end

    def self.critical_stock
      ChannelInventory.where('quantity <= reserved_quantity + 3').where('last_synced_at > ?', 15.minutes.ago)
    end

    def self.overstocked(threshold = 1000)
      ChannelInventory.where('quantity >= ?', threshold).where('last_synced_at > ?', 1.hour.ago)
    end

    def self.recently_synced(timeframe = 1.hour)
      ChannelInventory.where('last_synced_at > ?', timeframe.ago)
    end

    def self.needs_attention
      ChannelInventory.where('attention_required = ? OR last_attention_at < ?', true, 30.minutes.ago)
    end
  end
end