# frozen_string_literal: true

module ChannelProduct
  module Presenters
    class ChannelProductPresenter
      def initialize(channel_product)
        @channel_product = channel_product
      end

      def as_json(options = {})
        {
          id: @channel_product.id,
          product_id: @channel_product.product_id,
          sales_channel_id: @channel_product.sales_channel_id,
          available: @channel_product.available,
          effective_price: @channel_product.effective_price,
          effective_inventory: @channel_product.effective_inventory,
          available_for_purchase: @channel_product.available_for_purchase?,
          channel_title: @channel_product.channel_title,
          channel_description: @channel_product.channel_description,
          channel_images: @channel_product.channel_images,
          last_synced_at: @channel_product.last_synced_at,
          availability_updated_at: @channel_product.availability_updated_at,
          created_at: @channel_product.created_at,
          updated_at: @channel_product.updated_at,
          product: product_summary,
          sales_channel: channel_summary,
          health_status: health_summary
        }.merge(options)
      end

      def to_api_response
        as_json.merge(
          _links: {
            self: "/api/channel_products/#{@channel_product.id}",
            product: "/api/products/#{@channel_product.product_id}",
            sales_channel: "/api/sales_channels/#{@channel_product.sales_channel_id}"
          }
        )
      end

      def to_dashboard_view
        as_json.merge(
          performance_metrics: performance_summary,
          business_insights: insights_summary,
          health_check: @channel_product.health_check
        )
      end

      private

      def product_summary
        product = @channel_product.product
        return nil unless product

        {
          id: product.id,
          name: product.name,
          description: product.description,
          base_price: product.price,
          stock_quantity: product.stock_quantity,
          active: product.active
        }
      end

      def channel_summary
        channel = @channel_product.sales_channel
        return nil unless channel

        {
          id: channel.id,
          name: channel.name,
          channel_type: channel.channel_type,
          status: channel.status,
          configuration: channel.configuration
        }
      end

      def health_summary
        health_check = @channel_product.health_check
        {
          healthy: health_check.healthy,
          critical_issues_count: health_check.critical_issues.size,
          warning_issues_count: health_check.warning_issues.size,
          last_checked: health_check.last_checked
        }
      end

      def performance_summary
        return {} unless @channel_product.last_synced_at

        {
          last_synced: @channel_product.last_synced_at,
          sync_freshness: sync_freshness_status,
          data_quality: data_quality_score
        }
      end

      def insights_summary
        {
          optimization_opportunities: [],
          risk_factors: [],
          recommendations: []
        }
      end

      def sync_freshness_status
        return 'fresh' if @channel_product.last_synced_at > 15.minutes.ago
        return 'stale' if @channel_product.last_synced_at < 1.hour.ago
        'normal'
      end

      def data_quality_score
        score = 100

        score -= 30 unless @channel_product.product&.active?
        score -= 30 unless @channel_product.sales_channel&.active?
        score -= 20 if @channel_product.last_synced_at&. < 1.hour.ago
        score -= 10 if @channel_product.channel_specific_data.blank?

        [score, 0].max
      end
    end
  end
end