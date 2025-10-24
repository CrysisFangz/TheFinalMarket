class ExchangeRatePresenter
  def initialize(exchange_rate)
    @exchange_rate = exchange_rate
  end

  def as_json(options = {})
    {
      id: @exchange_rate.id,
      currency_id: @exchange_rate.currency_id,
      rate: @exchange_rate.rate,
      source: @exchange_rate.source,
      created_at: @exchange_rate.created_at,
      updated_at: @exchange_rate.updated_at,
      significant_change: @exchange_rate.significant_change?,
      currency_code: @exchange_rate.currency.code,
      currency_name: @exchange_rate.currency.name
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end