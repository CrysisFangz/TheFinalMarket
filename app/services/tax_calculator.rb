# TaxCalculator Service
# Handles tax calculations with performance optimizations and error handling
class TaxCalculator
  include ActiveSupport::Memoizable

  # Cache key for tax calculations
  CACHE_KEY_PREFIX = 'tax_calculation'

  # Calculate tax amount for a given tax rate and amount
  # @param tax_rate [TaxRate] the tax rate object
  # @param amount_cents [Integer] amount in cents
  # @return [Integer] tax amount in cents
  def self.calculate_tax(tax_rate, amount_cents)
    validate_inputs(tax_rate, amount_cents)

    cache_key = "#{CACHE_KEY_PREFIX}:#{tax_rate.id}:#{amount_cents}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      (amount_cents * tax_rate.rate / 100.0).round
    end
  rescue => e
    handle_error(e, 'calculate_tax')
    0 # fallback
  end

  # Get tax-inclusive amount
  # @param tax_rate [TaxRate] the tax rate object
  # @param amount_cents [Integer] amount in cents
  # @return [Integer] total amount including tax
  def self.with_tax(tax_rate, amount_cents)
    validate_inputs(tax_rate, amount_cents)

    amount_cents + calculate_tax(tax_rate, amount_cents)
  rescue => e
    handle_error(e, 'with_tax')
    amount_cents # fallback
  end

  # Get tax-exclusive amount if tax is included in price
  # @param tax_rate [TaxRate] the tax rate object
  # @param amount_cents [Integer] amount in cents
  # @return [Integer] amount without tax
  def self.without_tax(tax_rate, amount_cents)
    validate_inputs(tax_rate, amount_cents)

    return amount_cents unless tax_rate.included_in_price?

    cache_key = "#{CACHE_KEY_PREFIX}:without:#{tax_rate.id}:#{amount_cents}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      (amount_cents / (1 + tax_rate.rate / 100.0)).round
    end
  rescue => e
    handle_error(e, 'without_tax')
    amount_cents # fallback
  end

  private

  def self.validate_inputs(tax_rate, amount_cents)
    raise ArgumentError, 'TaxRate must be provided' unless tax_rate.is_a?(TaxRate)
    raise ArgumentError, 'Amount must be a non-negative integer' unless amount_cents.is_a?(Integer) && amount_cents >= 0
  end

  def self.handle_error(error, method)
    Rails.logger.error("TaxCalculator error in #{method}: #{error.message}")
    # Optionally, integrate with monitoring tools like Sentry
    # Sentry.capture_exception(error)
  end
end