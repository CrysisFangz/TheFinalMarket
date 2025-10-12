class ExchangeRateService
  API_PROVIDERS = {
    fixer: 'https://api.fixer.io/latest',
    openexchangerates: 'https://openexchangerates.org/api/latest.json',
    currencyapi: 'https://api.currencyapi.com/v3/latest',
    exchangerate: 'https://api.exchangerate-api.com/v4/latest'
  }.freeze
  
  # Fetch exchange rate from external API
  def self.fetch_rate(from_currency_code, to_currency_code)
    return 1.0 if from_currency_code == to_currency_code
    
    # Try each provider until one succeeds
    API_PROVIDERS.each do |provider, _url|
      begin
        rate = fetch_from_provider(provider, from_currency_code, to_currency_code)
        return rate if rate
      rescue => e
        Rails.logger.error "Failed to fetch rate from #{provider}: #{e.message}"
        next
      end
    end
    
    # Fallback to cached rate
    fallback_rate(from_currency_code, to_currency_code)
  end
  
  # Update all exchange rates
  def self.update_all_rates
    base_currency = Currency.base_currency
    currencies = Currency.active.where.not(id: base_currency.id)
    
    rates = fetch_all_rates(base_currency.code)
    return unless rates
    
    currencies.each do |currency|
      rate_value = rates[currency.code]
      next unless rate_value
      
      ExchangeRate.create!(
        currency: currency,
        rate: rate_value,
        source: detect_source,
        metadata: { updated_at: Time.current }
      )
    end
  end
  
  # Convert amount between currencies
  def self.convert(amount_cents, from_currency, to_currency)
    return amount_cents if from_currency.code == to_currency.code
    
    rate = ExchangeRate.cross_rate(from_currency, to_currency)
    (amount_cents * rate).round
  end
  
  # Get conversion rate
  def self.get_rate(from_currency, to_currency)
    return 1.0 if from_currency.code == to_currency.code
    
    ExchangeRate.cross_rate(from_currency, to_currency)
  end
  
  private
  
  def self.fetch_from_provider(provider, from_code, to_code)
    case provider
    when :fixer
      fetch_from_fixer(from_code, to_code)
    when :openexchangerates
      fetch_from_openexchangerates(from_code, to_code)
    when :currencyapi
      fetch_from_currencyapi(from_code, to_code)
    when :exchangerate
      fetch_from_exchangerate(from_code, to_code)
    end
  end
  
  def self.fetch_from_fixer(from_code, to_code)
    api_key = ENV['FIXER_API_KEY']
    return nil unless api_key
    
    url = "#{API_PROVIDERS[:fixer]}?access_key=#{api_key}&base=#{from_code}&symbols=#{to_code}"
    response = HTTP.get(url)
    data = JSON.parse(response.body)
    
    data.dig('rates', to_code)
  end
  
  def self.fetch_from_openexchangerates(from_code, to_code)
    api_key = ENV['OPENEXCHANGERATES_API_KEY']
    return nil unless api_key
    
    url = "#{API_PROVIDERS[:openexchangerates]}?app_id=#{api_key}&base=#{from_code}&symbols=#{to_code}"
    response = HTTP.get(url)
    data = JSON.parse(response.body)
    
    data.dig('rates', to_code)
  end
  
  def self.fetch_from_currencyapi(from_code, to_code)
    api_key = ENV['CURRENCYAPI_KEY']
    return nil unless api_key
    
    url = "#{API_PROVIDERS[:currencyapi]}?apikey=#{api_key}&base_currency=#{from_code}&currencies=#{to_code}"
    response = HTTP.get(url)
    data = JSON.parse(response.body)
    
    data.dig('data', to_code, 'value')
  end
  
  def self.fetch_from_exchangerate(from_code, to_code)
    url = "#{API_PROVIDERS[:exchangerate]}/#{from_code}"
    response = HTTP.get(url)
    data = JSON.parse(response.body)
    
    data.dig('rates', to_code)
  end
  
  def self.fetch_all_rates(base_code)
    # Try exchangerate-api first (free, no API key needed)
    begin
      url = "#{API_PROVIDERS[:exchangerate]}/#{base_code}"
      response = HTTP.timeout(10).get(url)
      data = JSON.parse(response.body)
      return data['rates'] if data['rates']
    rescue => e
      Rails.logger.error "Failed to fetch all rates: #{e.message}"
    end
    
    # Try other providers with API keys
    api_key = ENV['OPENEXCHANGERATES_API_KEY']
    if api_key
      begin
        url = "#{API_PROVIDERS[:openexchangerates]}?app_id=#{api_key}&base=#{base_code}"
        response = HTTP.timeout(10).get(url)
        data = JSON.parse(response.body)
        return data['rates'] if data['rates']
      rescue => e
        Rails.logger.error "Failed to fetch from OpenExchangeRates: #{e.message}"
      end
    end
    
    nil
  end
  
  def self.fallback_rate(from_code, to_code)
    # Try to get the most recent rate from database
    from_currency = Currency.find_by(code: from_code)
    to_currency = Currency.find_by(code: to_code)
    
    return 1.0 unless from_currency && to_currency
    
    ExchangeRate.latest_rate(from_currency, to_currency) || 1.0
  end
  
  def self.detect_source
    if ENV['FIXER_API_KEY']
      :api_fixer
    elsif ENV['OPENEXCHANGERATES_API_KEY']
      :api_openexchangerates
    elsif ENV['CURRENCYAPI_KEY']
      :api_currencyapi
    else
      :api_exchangerate
    end
  end
end

