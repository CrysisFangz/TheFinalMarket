class RateCalculationService
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
end