# frozen_string_literal: true

module ChannelProduct
  module Services
    class HealthCheckService
      def check_health(channel_product)
        issues = []

        issues << 'Product inactive' unless channel_product.product&.active?
        issues << 'Channel inactive' unless channel_product.sales_channel&.active?
        issues << 'No inventory' if channel_product.inventory.available_quantity <= 0
        issues << 'Pricing invalid' unless pricing_valid?(channel_product)
        issues << 'Sync stale' if sync_stale?(channel_product)
        issues << 'No recent performance data' if performance_data_stale?(channel_product)

        HealthCheckResult.new(
          healthy: issues.empty?,
          issues: issues,
          last_checked: Time.current,
          response_time: calculate_response_time
        )
      end

      private

      def pricing_valid?(channel_product)
        channel_product.pricing.effective_price > 0 &&
        channel_product.pricing.currency.present?
      rescue
        false
      end

      def sync_stale?(channel_product)
        channel_product.last_synced_at.nil? ||
        channel_product.last_synced_at < 1.hour.ago
      end

      def performance_data_stale?(channel_product)
        # Implementation for checking performance data freshness
        false
      end

      def calculate_response_time
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        # Simulate health check work
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      end

      class HealthCheckResult
        attr_reader :healthy, :issues, :last_checked, :response_time

        def initialize(healthy:, issues:, last_checked:, response_time:)
          @healthy = healthy
          @issues = issues
          @last_checked = last_checked
          @response_time = response_time
        end

        def critical_issues
          @issues.select { |issue| critical_issue?(issue) }
        end

        def warning_issues
          @issues - critical_issues
        end

        private

        def critical_issue?(issue)
          ['Product inactive', 'Channel inactive', 'Pricing invalid'].include?(issue)
        end
      end
    end
  end
end