# frozen_string_literal: true

module ChannelProduct
  module Queries
    class ChannelProductQueries
      def self.find_available_products(sales_channel_id)
        ChannelProduct.available
                    .joins(:product)
                    .where(sales_channel_id: sales_channel_id)
                    .where(products: { active: true })
                    .where('products.stock_quantity > 0')
      end

      def self.find_products_by_channel_type(channel_types)
        ChannelProduct.joins(:sales_channel)
                    .where(sales_channels: { channel_type: channel_types })
                    .includes(:product)
      end

      def self.find_recently_updated(time_threshold = 1.hour.ago)
        ChannelProduct.where('updated_at > ?', time_threshold)
                    .includes(:product, :sales_channel)
      end

      def self.find_by_performance_range(min_revenue: nil, max_revenue: nil, time_range: 30.days)
        query = ChannelProduct.joins(:product, :sales_channel)

        if min_revenue.present?
          query = query.where('daily_revenue >= ?', min_revenue)
        end

        if max_revenue.present?
          query = query.where('daily_revenue <= ?', max_revenue)
        end

        query
      end

      def self.find_stale_synchronizations(threshold = 2.hours.ago)
        ChannelProduct.where('last_synced_at IS NULL OR last_synced_at < ?',
                           threshold)
                    .includes(:product, :sales_channel)
      end

      def self.find_healthy_products
        ChannelProduct.available
                    .joins(:product, :sales_channel)
                    .where(products: { active: true })
                    .where(sales_channels: { status: :active })
                    .where('last_synced_at > ?', 1.hour.ago)
      end

      def self.find_products_needing_attention
        ChannelProduct.unavailable
                    .or(ChannelProduct.where('last_synced_at < ?', 2.hours.ago))
                    .or(ChannelProduct.where(products: { active: false }))
                    .or(ChannelProduct.where(sales_channels: { status: :inactive }))
                    .includes(:product, :sales_channel)
      end

      def self.count_by_channel_type
        ChannelProduct.joins(:sales_channel)
                    .group('sales_channels.channel_type')
                    .count
      end

      def self.average_sync_age
        result = ChannelProduct.where.not(last_synced_at: nil)
                              .average('EXTRACT(EPOCH FROM (NOW() - last_synced_at))')
        result.to_f
      end

      def self.performance_summary(time_range = 30.days)
        start_date = time_range.is_a?(Range) ? time_range.begin : time_range.days.ago

        ChannelProduct.joins(:product, :sales_channel)
                    .where('last_synced_at > ?', start_date)
                    .group('sales_channels.channel_type')
                    .select(
                      'sales_channels.channel_type',
                      'COUNT(*) as product_count',
                      'AVG(EXTRACT(EPOCH FROM (NOW() - last_synced_at))) as avg_sync_age_seconds',
                      'SUM(CASE WHEN available = true THEN 1 ELSE 0 END) as available_count'
                    )
      end
    end
  end
end