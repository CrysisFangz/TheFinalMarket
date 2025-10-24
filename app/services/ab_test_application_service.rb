# frozen_string_literal: true

# Service for applying A/B test winners to products.
# Ensures atomic operations and maintains data consistency.
class AbTestApplicationService
  # Applies the winning variant to the product.
  # @param ab_test [ProductAbTest] The A/B test with a winner.
  # @return [Boolean] True if applied successfully.
  def self.apply_winner(ab_test)
    return false unless ab_test.winning_variant_id

    winner = ab_test.ab_test_variants.find(ab_test.winning_variant_id)

    ab_test.transaction do
      case ab_test.test_type.to_sym
      when :title
        ab_test.product.update!(name: winner.variant_data['title'])
      when :description
        ab_test.product.update!(description: winner.variant_data['description'])
      when :price
        ab_test.product.update!(price_cents: winner.variant_data['price_cents'])
      when :call_to_action
        ab_test.product.update!(cta_text: winner.variant_data['cta_text'])
      end

      ab_test.update!(applied: true, applied_at: Time.current)
    end

    # Publish event
    EventPublisher.publish('ab_test_winner_applied', {
      test_id: ab_test.id,
      product_id: ab_test.product_id,
      winner_id: winner.id
    })

    true
  rescue StandardError => e
    Rails.logger.error("Failed to apply winner for A/B test #{ab_test.id}: #{e.message}")
    false
  end
end