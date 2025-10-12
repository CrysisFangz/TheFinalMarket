class CountriesController < ApplicationController
  # GET /countries
  def index
    countries = Country.active.by_name
    
    # Filter by shipping support if requested
    countries = countries.supported if params[:shipping_supported] == 'true'
    
    render json: {
      countries: countries.map do |country|
        {
          code: country.code,
          name: country.name,
          native_name: country.native_name,
          currency_code: country.currency_code,
          locale_code: country.locale_code,
          timezone: country.timezone,
          phone_code: country.phone_code,
          continent: country.continent,
          supported_for_shipping: country.supported_for_shipping,
          requires_customs: country.requires_customs
        }
      end
    }
  end
  
  # GET /countries/:code
  def show
    country = Country.find_by_code(params[:code].upcase)
    
    if country.nil?
      return render json: { error: 'Country not found' }, status: :not_found
    end
    
    # Get shipping zone
    zone = country.shipping_zone
    
    # Get tax rate
    tax_rate = country.tax_rate_for
    
    render json: {
      code: country.code,
      name: country.name,
      native_name: country.native_name,
      currency: {
        code: country.currency_code,
        name: country.currency&.name,
        symbol: country.currency&.symbol
      },
      locale_code: country.locale_code,
      timezone: country.timezone,
      phone_code: country.phone_code,
      continent: country.continent,
      active: country.active,
      supported_for_shipping: country.supported_for_shipping,
      requires_customs: country.requires_customs,
      shipping_zone: zone ? {
        code: zone.code,
        name: zone.name,
        priority: zone.priority
      } : nil,
      tax_rate: tax_rate ? {
        name: tax_rate.name,
        type: tax_rate.tax_type,
        rate: tax_rate.rate,
        included_in_price: tax_rate.included_in_price
      } : nil
    }
  end
end

