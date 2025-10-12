class InternationalizationService
  attr_reader :user, :request
  
  def initialize(user = nil, request = nil)
    @user = user
    @request = request
  end
  
  # Detect and set locale
  def detect_locale
    user_locale || browser_locale || default_locale
  end
  
  # Detect and set currency
  def detect_currency
    user_currency || geo_currency || locale_currency || default_currency
  end
  
  # Get localized content
  def localized_content(model, attribute)
    locale = I18n.locale.to_s
    
    # Try to get translated content
    translation = model.translations.find_by(locale: locale, attribute: attribute)
    return translation.value if translation
    
    # Fallback to default locale
    default_translation = model.translations.find_by(
      locale: I18n.default_locale.to_s,
      attribute: attribute
    )
    return default_translation.value if default_translation
    
    # Fallback to original attribute
    model.send(attribute)
  end
  
  # Format price for user
  def format_price(amount_cents, currency = nil)
    currency ||= detect_currency
    
    # Convert to user's currency if needed
    base_currency = Currency.base_currency
    if currency.code != base_currency.code
      amount_cents = ExchangeRateService.convert(amount_cents, base_currency, currency)
    end
    
    currency.format_amount(amount_cents)
  end
  
  # Get shipping options for user
  def shipping_options(country_code, weight_grams)
    country = Country.find_by_code(country_code)
    return [] unless country
    
    zone = country.shipping_zone
    return [] unless zone
    
    zone.shipping_rates.active.map do |rate|
      next unless rate.applies_to_weight?(weight_grams)
      
      {
        service_level: rate.service_level,
        cost_cents: rate.calculate_cost(weight_grams),
        delivery_estimate: rate.delivery_estimate,
        currency: country.currency
      }
    end.compact
  end
  
  # Calculate total with tax
  def calculate_total_with_tax(subtotal_cents, country_code, product_category = nil)
    country = Country.find_by_code(country_code)
    return subtotal_cents unless country
    
    tax = country.calculate_tax(subtotal_cents, product_category)
    subtotal_cents + tax
  end
  
  # Get user's timezone
  def detect_timezone
    user_timezone || geo_timezone || browser_timezone || default_timezone
  end
  
  # Format date/time for user
  def format_datetime(datetime)
    timezone = detect_timezone
    datetime.in_time_zone(timezone).strftime(I18n.t('time.formats.default'))
  end
  
  # Get supported locales
  def self.supported_locales
    I18n.available_locales
  end
  
  # Get supported currencies
  def self.supported_currencies
    Currency.supported.active
  end
  
  # Get supported countries
  def self.supported_countries
    Country.supported.active.by_name
  end
  
  private
  
  def user_locale
    return nil unless user
    user.locale || user.country&.locale
  end
  
  def browser_locale
    return nil unless request
    
    # Parse Accept-Language header
    accept_language = request.env['HTTP_ACCEPT_LANGUAGE']
    return nil unless accept_language
    
    # Get first preferred language
    preferred = accept_language.split(',').first
    return nil unless preferred
    
    locale_code = preferred.split(';').first.strip
    
    # Check if we support this locale
    I18n.available_locales.include?(locale_code.to_sym) ? locale_code : nil
  end
  
  def default_locale
    I18n.default_locale.to_s
  end
  
  def user_currency
    return nil unless user
    user.currency_preference&.currency
  end
  
  def geo_currency
    return nil unless request
    
    # Get country from IP geolocation
    country_code = detect_country_from_ip
    return nil unless country_code
    
    country = Country.find_by_code(country_code)
    country&.currency
  end
  
  def locale_currency
    Currency.detect_from_locale
  end
  
  def default_currency
    Currency.base_currency
  end
  
  def user_timezone
    return nil unless user
    user.timezone
  end
  
  def geo_timezone
    return nil unless request
    
    # Get timezone from IP geolocation
    country_code = detect_country_from_ip
    return nil unless country_code
    
    country = Country.find_by_code(country_code)
    country&.timezone
  end
  
  def browser_timezone
    # This would typically come from JavaScript
    # For now, return nil
    nil
  end
  
  def default_timezone
    'UTC'
  end
  
  def detect_country_from_ip
    return nil unless request
    
    # Get IP address
    ip = request.remote_ip
    return nil if ip == '127.0.0.1' || ip == '::1'
    
    # Use geocoding service (Geocoder gem)
    begin
      result = Geocoder.search(ip).first
      result&.country_code
    rescue => e
      Rails.logger.error "Failed to geocode IP: #{e.message}"
      nil
    end
  end
end

