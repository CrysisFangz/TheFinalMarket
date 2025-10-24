# frozen_string_literal: true

class ScoringCalculator
  def initialize(profile)
    @profile = profile
  end

  def recalculate_scores
    {
      lifetime_value_score: calculate_ltv_score,
      purchase_frequency_score: calculate_frequency_score,
      price_sensitivity_score: calculate_price_sensitivity,
      brand_loyalty_score: calculate_brand_loyalty,
      impulse_buying_score: calculate_impulse_score,
      research_intensity_score: calculate_research_score,
      weekend_shopping_score: calculate_weekend_score,
      night_shopping_score: calculate_night_score,
      mobile_usage_score: calculate_mobile_score
    }
  end

  private

  def calculate_ltv_score
    total_spent = @profile.purchase_history&.sum { |p| p[:total] } || 0
    [total_spent / 10000.0, 100].min.round
  end

  def calculate_frequency_score
    return 0 if @profile.purchase_history.blank?

    purchases_per_month = @profile.purchase_history.count / 12.0
    [purchases_per_month * 20, 100].min.round
  end

  def calculate_price_sensitivity
    return 50 if @profile.purchase_history.blank?

    avg_price = @profile.purchase_history.sum { |p| p[:total] } / @profile.purchase_history.count.to_f
    avg_price < 5000 ? 80 : 30
  end

  def calculate_brand_loyalty
    # Enhanced: Check brand repetition in purchases
    brands = @profile.purchase_history&.flat_map { |p| p[:categories] } || []
    unique_brands = brands.uniq.count
    total_brands = brands.count
    return 50 if total_brands.zero?

    loyalty_ratio = unique_brands.to_f / total_brands
    [loyalty_ratio * 100, 100].min.round
  end

  def calculate_impulse_score
    # Enhanced: Check time between view and purchase
    50 # Placeholder for now
  end

  def calculate_research_score
    search_count = @profile.search_history&.count || 0
    [search_count / 10.0 * 100, 100].min.round
  end

  def calculate_weekend_score
    return 50 if @profile.purchase_history.blank?

    weekend_purchases = @profile.purchase_history.count { |p| [0, 6].include?(p[:date].wday) }
    (@profile.purchase_history.count.zero? ? 0 : (weekend_purchases.to_f / @profile.purchase_history.count * 100)).round
  end

  def calculate_night_score
    return 50 if @profile.purchase_history.blank?

    night_purchases = @profile.purchase_history.count { |p| p[:date].hour >= 20 || p[:date].hour < 6 }
    (@profile.purchase_history.count.zero? ? 0 : (night_purchases.to_f / @profile.purchase_history.count * 100)).round
  end

  def calculate_mobile_score
    # Enhanced: Would check device usage
    60
  end
end