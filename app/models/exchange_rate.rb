class ExchangeRate < ApplicationRecord
  belongs_to :currency
  
  validates :rate, presence: true, numericality: { greater_than: 0 }
  validates :source, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_currency, ->(currency) { where(currency: currency) }
  scope :today, -> { where('created_at >= ?', Date.current.beginning_of_day) }
  
  # Sources for exchange rates
  enum source: {
    manual: 0,
    api_fixer: 1,
    api_openexchangerates: 2,
    api_currencyapi: 3,
    api_exchangerate: 4
  }
  
  # Get the latest rate for a currency pair
  def self.latest_rate(from_currency, to_currency)
    return 1.0 if from_currency.code == to_currency.code
    
    # Try to find recent rate (within last 24 hours)
    rate_record = where(currency: to_currency)
                   .where('created_at > ?', 24.hours.ago)
                   .order(created_at: :desc)
                   .first
    
    rate_record&.rate
  end
  
  # Calculate cross rate between two currencies
  def self.cross_rate(from_currency, to_currency)
    return 1.0 if from_currency.code == to_currency.code
    
    base_currency = Currency.base_currency
    
    # If one of them is base currency
    if from_currency.is_base?
      return to_currency.current_exchange_rate
    elsif to_currency.is_base?
      return 1.0 / from_currency.current_exchange_rate
    end
    
    # Calculate cross rate through base currency
    from_to_base = from_currency.current_exchange_rate
    to_to_base = to_currency.current_exchange_rate
    
    return 1.0 unless from_to_base && to_to_base
    
    to_to_base / from_to_base
  end
  
  # Check if rate has changed significantly
  def significant_change?(threshold_percentage = 2)
    previous_rate = currency.exchange_rates
                           .where('created_at < ?', created_at)
                           .order(created_at: :desc)
                           .first
    
    return false unless previous_rate
    
    change_percentage = ((rate - previous_rate.rate).abs / previous_rate.rate * 100)
    change_percentage >= threshold_percentage
  end
end

