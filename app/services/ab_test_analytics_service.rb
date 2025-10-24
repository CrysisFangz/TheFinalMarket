# frozen_string_literal: true

# Service for A/B test analytics, including results calculation and statistical significance.
# Optimized with caching for performance-critical operations.
class AbTestAnalyticsService
  # Generates comprehensive results for an A/B test.
  # @param ab_test [ProductAbTest] The A/B test.
  # @return [Hash] The test results.
  def self.generate_results(ab_test)
    cache_key = "ab_test_results_#{ab_test.id}_#{ab_test.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      variants_data = ab_test.ab_test_variants.map do |variant|
        impressions = ab_test.ab_test_impressions.where(ab_test_variant: variant)
        conversions = impressions.where(converted: true)

        {
          variant: variant,
          impressions: impressions.count,
          conversions: conversions.count,
          conversion_rate: calculate_conversion_rate(impressions, conversions),
          revenue: conversions.sum(:revenue_cents) / 100.0,
          average_order_value: calculate_aov(conversions),
          statistical_significance: calculate_significance(ab_test, variant)
        }
      end

      {
        test_name: ab_test.test_name,
        test_type: ab_test.test_type,
        status: ab_test.status,
        started_at: ab_test.started_at,
        duration_days: duration_days(ab_test),
        variants: variants_data,
        winner: winning_variant(ab_test),
        recommendation: generate_recommendation(ab_test)
      }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to generate results for A/B test #{ab_test.id}: #{e.message}")
    raise ArgumentError, "Failed to generate test results: #{e.message}"
  end

  # Checks if the test is statistically significant.
  # @param ab_test [ProductAbTest] The A/B test.
  # @return [Boolean] True if significant.
  def self.statistically_significant?(ab_test)
    return false if ab_test.ab_test_variants.count < 2

    variants = ab_test.ab_test_variants.limit(2)
    significance = calculate_significance_between(ab_test, variants.first, variants.second)

    significance > 95
  end

  private

  def self.duration_days(ab_test)
    return 0 unless ab_test.started_at

    end_time = ab_test.completed_at || Time.current
    ((end_time - ab_test.started_at) / 1.day).round
  end

  def self.calculate_conversion_rate(impressions, conversions)
    return 0 if impressions.count.zero?

    (conversions.count.to_f / impressions.count * 100).round(2)
  end

  def self.calculate_aov(conversions)
    return 0 if conversions.count.zero?

    (conversions.sum(:revenue_cents) / conversions.count.to_f / 100).round(2)
  end

  def self.calculate_significance(ab_test, variant)
    return 0 if ab_test.ab_test_variants.count < 2

    control = ab_test.ab_test_variants.where(is_control: true).first || ab_test.ab_test_variants.first
    return 0 if variant == control

    calculate_significance_between(ab_test, control, variant)
  end

  def self.calculate_significance_between(ab_test, variant_a, variant_b)
    impressions_a = ab_test.ab_test_impressions.where(ab_test_variant: variant_a).count
    conversions_a = ab_test.ab_test_impressions.where(ab_test_variant: variant_a, converted: true).count

    impressions_b = ab_test.ab_test_impressions.where(ab_test_variant: variant_b).count
    conversions_b = ab_test.ab_test_impressions.where(ab_test_variant: variant_b, converted: true).count

    return 0 if impressions_a.zero? || impressions_b.zero?

    rate_a = conversions_a.to_f / impressions_a
    rate_b = conversions_b.to_f / impressions_b

    pooled_rate = (conversions_a + conversions_b).to_f / (impressions_a + impressions_b)

    se = Math.sqrt(pooled_rate * (1 - pooled_rate) * (1.0/impressions_a + 1.0/impressions_b))

    return 0 if se.zero?

    z_score = ((rate_b - rate_a) / se).abs

    # Convert z-score to confidence level
    if z_score > 2.58
      99
    elsif z_score > 1.96
      95
    elsif z_score > 1.65
      90
    else
      50
    end
  end

  def self.winning_variant(ab_test)
    return nil unless ab_test.winning_variant_id

    ab_test.ab_test_variants.find(ab_test.winning_variant_id)
  end

  def self.generate_recommendation(ab_test)
    return "Test is still running" if ab_test.active?
    return "Not enough data" if ab_test.ab_test_impressions.count < 100

    if statistically_significant?(ab_test)
      winner = winning_variant(ab_test)
      "Apply variant '#{winner.variant_name}' - statistically significant improvement"
    else
      "No clear winner. Consider running test longer or trying different variants"
    end
  end
end