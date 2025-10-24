class RateLookupService
  def self.latest_rate(from_currency, to_currency)
    return 1.0 if from_currency.code == to_currency.code

    Rails.cache.fetch("exchange_rate:#{from_currency.code}:#{to_currency.code}", expires_in: 1.hour) do
      # Try to find recent rate (within last 24 hours)
      rate_record = ExchangeRate.where(currency: to_currency)
                               .where('created_at > ?', 24.hours.ago)
                               .order(created_at: :desc)
                               .first

      rate_record&.rate
    end
  end
end