# frozen_string_literal: true

# Service for managing A/B test lifecycle operations (start, stop, pause).
# Ensures data integrity and provides audit trails for all operations.
class AbTestManagementService
  # Starts an A/B test if conditions are met.
  # @param ab_test [ProductAbTest] The A/B test to start.
  # @return [Boolean] True if started successfully.
  def self.start_test(ab_test)
    return false unless ab_test.draft?
    return false if ab_test.ab_test_variants.count < 2

    ab_test.update!(
      status: :active,
      started_at: Time.current
    )

    # Publish event
    EventPublisher.publish('ab_test_started', { test_id: ab_test.id, product_id: ab_test.product_id })
    true
  rescue StandardError => e
    Rails.logger.error("Failed to start A/B test #{ab_test.id}: #{e.message}")
    false
  end

  # Stops an A/B test and determines the winner.
  # @param ab_test [ProductAbTest] The A/B test to stop.
  # @return [Boolean] True if stopped successfully.
  def self.stop_test(ab_test)
    ab_test.update!(
      status: :completed,
      completed_at: Time.current
    )

    # Determine and set winner
    determine_winner(ab_test)

    # Publish event
    EventPublisher.publish('ab_test_completed', { test_id: ab_test.id, winner_id: ab_test.winning_variant_id })
    true
  rescue StandardError => e
    Rails.logger.error("Failed to stop A/B test #{ab_test.id}: #{e.message}")
    false
  end

  private

  def self.determine_winner(ab_test)
    return if ab_test.ab_test_variants.count < 2

    winner = ab_test.ab_test_variants.max_by do |variant|
      impressions = ab_test.ab_test_impressions.where(ab_test_variant: variant)
      conversions = impressions.where(converted: true)
      calculate_conversion_rate(impressions, conversions)
    end

    ab_test.update!(winning_variant_id: winner.id)
  end

  def self.calculate_conversion_rate(impressions, conversions)
    return 0 if impressions.count.zero?

    (conversions.count.to_f / impressions.count * 100).round(2)
  end
end