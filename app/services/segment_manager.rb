# frozen_string_literal: true

class SegmentManager
  def initialize(profile)
    @profile = profile
  end

  def micro_segment
    segments = []

    # Behavioral segments
    segments << "high_value" if @profile.lifetime_value_score > 80
    segments << "frequent_buyer" if @profile.purchase_frequency_score > 70
    segments << "deal_seeker" if @profile.price_sensitivity_score > 60
    segments << "brand_loyal" if @profile.brand_loyalty_score > 70
    segments << "impulse_buyer" if @profile.impulse_buying_score > 60
    segments << "researcher" if @profile.research_intensity_score > 70

    # Category preferences
    @profile.top_categories.each do |category|
      segments << "#{category}_enthusiast"
    end

    # Time-based
    segments << "weekend_shopper" if @profile.weekend_shopping_score > 60
    segments << "night_owl" if @profile.night_shopping_score > 60

    # Device preference
    segments << "mobile_first" if @profile.mobile_usage_score > 70

    segments
  end

  def update_segments
    current_segments = micro_segment

    current_segments.each do |segment_name|
      @profile.user_segments.find_or_create_by!(segment_name: segment_name)
    end

    # Remove old segments
    @profile.user_segments.where.not(segment_name: current_segments).destroy_all
  end
end