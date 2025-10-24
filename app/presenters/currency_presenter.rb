class CurrencyPresenter
  attr_reader :currency

  def initialize(currency)
    @currency = currency
  end

  def as_json(options = {})
    {
      id: currency.id,
      code: currency.code,
      name: currency.name,
      symbol: currency.symbol,
      active: currency.active,
      supported: currency.supported,
      popularity_rank: currency.popularity_rank,
      decimal_places: currency.decimal_places,
      symbol_position: currency.symbol_position,
      thousands_separator: currency.thousands_separator,
      decimal_separator: currency.decimal_separator,
      is_base: currency.is_base
    }.merge(options)
  end

  def for_api
    as_json
  end
end