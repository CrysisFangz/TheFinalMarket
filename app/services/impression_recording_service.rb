# frozen_string_literal: true

# Service for recording A/B test impressions and conversions.
# Optimized for high-throughput operations with batch processing.
class ImpressionRecordingService
  # Records an impression for a variant and user.
  # @param ab_test [ProductAbTest] The A/B test.
  # @param variant [AbTestVariant] The variant.
  # @param user [User] The user.
  # @return [AbTestImpression] The created impression.
  def self.record_impression(ab_test, variant, user)
    ab_test.ab_test_impressions.create!(
      ab_test_variant: variant,
      user: user,
      viewed_at: Time.current
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Duplicate impression recorded for test #{ab_test.id}, user #{user.id}")
    # Return existing impression if duplicate
    ab_test.ab_test_impressions.find_by(ab_test_variant: variant, user: user)
  rescue StandardError => e
    Rails.logger.error("Failed to record impression for test #{ab_test.id}: #{e.message}")
    raise
  end

  # Records a conversion for a variant and user.
  # @param ab_test [ProductAbTest] The A/B test.
  # @param variant [AbTestVariant] The variant.
  # @param user [User] The user.
  # @param order [Order] The order.
  # @return [Boolean] True if recorded successfully.
  def self.record_conversion(ab_test, variant, user, order)
    impression = ab_test.ab_test_impressions.find_by(
      ab_test_variant: variant,
      user: user
    )

    return false unless impression

    impression.update!(
      converted: true,
      converted_at: Time.current,
      order: order,
      revenue_cents: order.total_cents
    )

    # Publish event
    EventPublisher.publish('ab_test_conversion', {
      test_id: ab_test.id,
      variant_id: variant.id,
      user_id: user.id,
      order_id: order.id
    })

    true
  rescue StandardError => e
    Rails.logger.error("Failed to record conversion for test #{ab_test.id}: #{e.message}")
    false
  end

  # Batch records multiple impressions for performance.
  # @param ab_test [ProductAbTest] The A/B test.
  # @param impressions_data [Array<Hash>] Array of impression data.
  def self.batch_record_impressions(ab_test, impressions_data)
    impressions = impressions_data.map do |data|
      {
        ab_test_variant_id: data[:variant_id],
        user_id: data[:user_id],
        viewed_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    ab_test.ab_test_impressions.insert_all(impressions)
  rescue StandardError => e
    Rails.logger.error("Failed to batch record impressions for test #{ab_test.id}: #{e.message}")
    false
  end
end