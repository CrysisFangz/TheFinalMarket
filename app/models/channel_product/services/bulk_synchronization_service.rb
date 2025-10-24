# frozen_string_literal: true

module ChannelProduct
  module Services
    class BulkSynchronizationService
      def bulk_sync(product_ids, sync_context = {})
        products = Product.where(id: product_ids).includes(:channel_products)

        results = products.flat_map do |product|
          product.channel_products.map do |channel_product|
            channel_product.sync_from_product!(sync_context)
          end
        end

        BulkSynchronizationResult.new(
          total_processed: results.size,
          successful: results.count(&:persisted?),
          failed: results.count { |r| r.errors.any? }
        )
      end

      class BulkSynchronizationResult
        attr_reader :total_processed, :successful, :failed

        def initialize(total_processed:, successful:, failed:)
          @total_processed = total_processed
          @successful = successful
          @failed = failed
        end

        def success_rate
          return 0.0 if @total_processed.zero?
          (@successful.to_f / @total_processed * 100).round(2)
        end

        def all_successful?
          @failed.zero?
        end
      end
    end
  end
end