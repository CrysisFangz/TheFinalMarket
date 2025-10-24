class ShippingZoneService
  include CircuitBreaker

  # Cache for zone lookups
  CACHE_KEY_PREFIX = 'shipping_zone:'
  CACHE_TTL = 1.hour

  # Find zone for a country with caching and optimization
  def self.for_country(country_code)
    cache_key = "#{CACHE_KEY_PREFIX}for_country:#{country_code}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      ShippingZone
        .joins(:countries)
        .where(countries: { code: country_code.upcase })
        .active
        .by_priority
        .includes(:shipping_rates)
        .first
    end
  end

  # Check if zone includes a country with caching
  def self.includes_country?(zone, country_code)
    cache_key = "#{CACHE_KEY_PREFIX}includes:#{zone.id}:#{country_code}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      zone.countries.exists?(code: country_code.upcase)
    end
  end

  # Get all active zones with countries preloaded
  def self.all_active_zones
    ShippingZone.active.by_priority.includes(:countries, :shipping_rates)
  end

  # Invalidate cache for a zone
  def self.invalidate_cache(zone_id)
    Rails.cache.delete_matched("#{CACHE_KEY_PREFIX}*:#{zone_id}:*")
  end
end