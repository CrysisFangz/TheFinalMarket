class ShippingRateCalculator
  include CircuitBreaker

  # Cache for rate calculations
  CACHE_KEY_PREFIX = 'shipping_rate:'
  CACHE_TTL = 30.minutes

  # Get shipping rate for weight and service with optimization
  def self.rate_for(zone, weight_grams, service_level = 'standard')
    cache_key = "#{CACHE_KEY_PREFIX}rate:#{zone.id}:#{weight_grams}:#{service_level}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      zone.shipping_rates
          .active
          .where(service_level: service_level)
          .where('min_weight_grams <= ?', weight_grams)
          .where('max_weight_grams >= ? OR max_weight_grams IS NULL', weight_grams)
          .order(min_weight_grams: :desc)
          .first
    end
  end

  # Calculate shipping cost with error handling
  def self.calculate_shipping(zone, weight_grams, service_level = 'standard')
    rate = rate_for(zone, weight_grams, service_level)
    return nil unless rate

    ShippingCostCalculator.calculate(rate, weight_grams)
  end

  # Get estimated delivery time
  def self.estimated_delivery_days(zone, service_level = 'standard')
    rate = zone.shipping_rates.active.find_by(service_level: service_level)
    return nil unless rate

    DeliveryEstimate.new(rate.min_delivery_days, rate.max_delivery_days)
  end

  # Get all shipping options for a zone and weight
  def self.shipping_options(zone, weight_grams, country)
    zone.shipping_rates.active.map do |rate|
      next unless ShippingRateValidator.applies_to_weight?(rate, weight_grams)

      cost_cents = ShippingCostCalculator.calculate(rate, weight_grams)

      {
        service_level: rate.service_level,
        carrier_name: rate.carrier_name,
        cost_cents: cost_cents,
        cost_formatted: country.currency.format_amount(cost_cents),
        delivery_estimate: DeliveryEstimate.new(rate.min_delivery_days, rate.max_delivery_days).to_s,
        min_delivery_days: rate.min_delivery_days,
        max_delivery_days: rate.max_delivery_days,
        includes_tracking: rate.includes_tracking,
        requires_signature: rate.requires_signature
      }
    end.compact
  end

  # Invalidate cache for a zone
  def self.invalidate_cache(zone_id)
    Rails.cache.delete_matched("#{CACHE_KEY_PREFIX}*:#{zone_id}:*")
  end
end