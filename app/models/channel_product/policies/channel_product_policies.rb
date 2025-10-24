# frozen_string_literal: true

module ChannelProduct
  module Policies
    class ChannelProductPolicies
      def self.can_purchase?(channel_product)
        new(channel_product).can_purchase?
      end

      def self.can_sync?(channel_product, user = nil)
        new(channel_product, user).can_sync?
      end

      def self.can_update_channel_data?(channel_product, user = nil)
        new(channel_product, user).can_update_channel_data?
      end

      def self.can_view_analytics?(channel_product, user = nil)
        new(channel_product, user).can_view_analytics?
      end

      def initialize(channel_product, user = nil)
        @channel_product = channel_product
        @user = user
      end

      def can_purchase?
        return false unless @channel_product.available?
        return false unless @channel_product.product&.active?
        return false unless @channel_product.sales_channel&.active?
        return false if @channel_product.inventory.available_quantity <= 0
        return false unless pricing_valid?

        true
      end

      def can_sync?
        return false unless @channel_product.product&.active?
        return false unless @channel_product.sales_channel&.active?
        return false unless user_can_manage_channel?

        true
      end

      def can_update_channel_data?
        return false unless @channel_product.product&.active?
        return false unless @channel_product.sales_channel&.active?
        return false unless user_can_manage_channel?

        true
      end

      def can_view_analytics?
        return false unless @channel_product.product&.active?
        return false unless @channel_product.sales_channel&.active?
        return false unless user_can_view_channel_analytics?

        true
      end

      def can_modify_availability?
        return false unless user_can_manage_channel?
        return false unless @channel_product.product&.active?

        true
      end

      def can_access_channel?(channel_id)
        return true if @user&.admin?

        @channel_product.sales_channel_id == channel_id &&
        user_can_access_channel?(channel_id)
      end

      def max_channel_data_size
        case @user&.role
        when 'admin' then 100_000 # 100KB for admins
        when 'seller' then 50_000  # 50KB for sellers
        else 10_000 # 10KB for others
        end
      end

      def allowed_channel_data_fields
        base_fields = %w[title description images specifications]

        if @user&.admin?
          base_fields + %w[metadata internal_notes]
        else
          base_fields
        end
      end

      private

      def pricing_valid?
        @channel_product.pricing.effective_price > 0 &&
        @channel_product.pricing.currency.present?
      rescue
        false
      end

      def user_can_manage_channel?
        return true if @user&.admin?

        @user&.seller? &&
        @user&.manages_channel?(@channel_product.sales_channel_id)
      end

      def user_can_view_channel_analytics?
        return true if @user&.admin?

        @user&.seller? &&
        @user&.can_view_analytics_for?(@channel_product.sales_channel_id)
      end

      def user_can_access_channel?(channel_id)
        return true if @user&.admin?

        @user&.accessible_channels&.include?(channel_id)
      end
    end

    class AvailabilityPolicy
      def self.can_mark_available?(channel_product, user = nil)
        policy = new(channel_product, user)
        policy.can_modify_availability? && policy.product_in_stock?
      end

      def self.can_mark_unavailable?(channel_product, user = nil)
        policy = new(channel_product, user)
        policy.can_modify_availability?
      end

      def initialize(channel_product, user = nil)
        @channel_product = channel_product
        @user = user
      end

      def can_modify_availability?
        return false unless @user
        return true if @user.admin?

        @user.seller? &&
        @user.manages_channel?(@channel_product.sales_channel_id)
      end

      def product_in_stock?
        @channel_product.product&.stock_quantity.to_i > 0
      rescue
        false
      end

      def channel_supports_availability_toggle?
        @channel_product.sales_channel&.supports_availability_management?
      end
    end

    class SynchronizationPolicy
      def self.can_force_sync?(channel_product, user = nil)
        policy = new(channel_product, user)
        policy.can_force_sync?
      end

      def self.can_bulk_sync?(channel_ids, user = nil)
        return false unless user&.admin?

        channel_ids.all? do |channel_id|
          user.can_manage_channel?(channel_id)
        end
      end

      def initialize(channel_product, user = nil)
        @channel_product = channel_product
        @user = user
      end

      def can_force_sync?
        return true if @user&.admin?

        @user&.seller? &&
        @user.manages_channel?(@channel_product.sales_channel_id) &&
        sync_stale?
      end

      def sync_stale?
        @channel_product.last_synced_at.nil? ||
        @channel_product.last_synced_at < 30.minutes.ago
      end

      def max_sync_frequency
        case @user&.role
        when 'admin' then 5.minutes
        when 'seller' then 15.minutes
        else 1.hour
        end
      end

      def can_sync_now?
        last_sync = @channel_product.last_synced_at
        return true unless last_sync

        Time.current - last_sync > max_sync_frequency
      end
    end
  end
end