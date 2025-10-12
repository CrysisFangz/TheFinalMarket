class CurrenciesController < ApplicationController
  # GET /currencies
  def index
    currencies = Currency.active.supported.by_popularity
    
    render json: {
      currencies: currencies.map do |currency|
        {
          code: currency.code,
          name: currency.name,
          symbol: currency.symbol,
          symbol_position: currency.symbol_position,
          decimal_places: currency.decimal_places,
          is_base: currency.is_base?,
          popularity_rank: currency.popularity_rank
        }
      end
    }
  end
  
  # GET /currencies/:code
  def show
    currency = Currency.find_by(code: params[:code].upcase)
    
    if currency.nil?
      return render json: { error: 'Currency not found' }, status: :not_found
    end
    
    render json: {
      code: currency.code,
      name: currency.name,
      symbol: currency.symbol,
      symbol_position: currency.symbol_position,
      decimal_places: currency.decimal_places,
      thousands_separator: currency.thousands_separator,
      decimal_separator: currency.decimal_separator,
      is_base: currency.is_base?,
      active: currency.active,
      supported: currency.supported,
      popularity_rank: currency.popularity_rank,
      current_rate: currency.current_exchange_rate
    }
  end
  
  # GET /currencies/:code/rate
  def rate
    from_code = params[:from] || Currency.base_currency.code
    to_code = params[:code].upcase
    
    from_currency = Currency.find_by(code: from_code.upcase)
    to_currency = Currency.find_by(code: to_code)
    
    if from_currency.nil? || to_currency.nil?
      return render json: { error: 'Currency not found' }, status: :not_found
    end
    
    rate = ExchangeRateService.get_rate(from_currency, to_currency)
    
    # Convert amount if provided
    converted_amount = nil
    if params[:amount]
      amount_cents = params[:amount].to_i
      converted_amount = ExchangeRateService.convert(amount_cents, from_currency, to_currency)
    end
    
    render json: {
      from: from_currency.code,
      to: to_currency.code,
      rate: rate,
      amount: params[:amount]&.to_i,
      converted_amount: converted_amount,
      timestamp: Time.current
    }
  end
end

