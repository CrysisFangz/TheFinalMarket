class ShippingController < ApplicationController
  # POST /shipping/calculate
  def calculate
    country_code = params[:country_code]
    weight_grams = params[:weight_grams].to_i
    
    country = Country.find_by_code(country_code)
    
    if country.nil?
      return render json: { error: 'Country not found' }, status: :not_found
    end
    
    unless country.supported_for_shipping?
      return render json: { error: 'Shipping not available to this country' }, status: :unprocessable_entity
    end
    
    zone = country.shipping_zone
    
    if zone.nil?
      return render json: { error: 'No shipping zone configured for this country' }, status: :unprocessable_entity
    end
    
    # Get all shipping options
    options = zone.shipping_rates.active.map do |rate|
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
    
    render json: {
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
  
  # GET /shipping/zones
  def zones
    zones = ShippingZone.active.by_priority.includes(:countries).map do |zone|
      {
        code: zone.code,
        name: zone.name,
        priority: zone.priority,
        countries: zone.countries.map { |c| { code: c.code, name: c.name } }
      }
    end
    
    render json: { zones: zones }
  end
end

