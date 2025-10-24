class RateAnalysisService
  def self.significant_change?(exchange_rate, threshold_percentage = 2)
    Rails.cache.fetch("exchange_rate:#{exchange_rate.id}:significant_change", expires_in: 1.hour) do
      previous_rate = exchange_rate.currency.exchange_rates
                                 .where('created_at < ?', exchange_rate.created_at)
                                 .order(created_at: :desc)
                                 .first

      return false unless previous_rate

      change_percentage = ((exchange_rate.rate - previous_rate.rate).abs / previous_rate.rate * 100)
      change_percentage >= threshold_percentage
    end
  end
end