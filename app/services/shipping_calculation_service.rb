class ShippingCalculationService
  include CircuitBreaker

  # Main method to calculate shipping options
  def self.calculate_shipping(country_code, weight_grams)
    country = Country.find_by_code(country_code)
    return { error: 'Country not found', status: :not_found } if country.nil?

    unless country.supported_for_shipping?
      return { error: 'Shipping not available to this country', status: :unprocessable_entity }
    end

    zone = ShippingZoneService.for_country(country_code)
    return { error: 'No shipping zone configured for this country', status: :unprocessable_entity } if zone.nil?

    options = ShippingRateCalculator.shipping_options(zone, weight_grams, country)

    {
      country: {
        code: country.code,
        name: country.name,
        currency: country.currency_code
      },
      shipping_zone: {
        code: zone.code,
        name: zone.name
      },
      options: options
    }
  end

  # Get all shipping zones
  def self.all_zones
    zones = ShippingZoneService.all_active_zones.map do |zone|
      {
        code: zone.code,
        name: zone.name,
        priority: zone.priority,
        countries: zone.countries.map { |c| { code: c.code, name: c.name } }
      }
    end

    { zones: zones }
  end
end