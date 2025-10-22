# frozen_string_literal: true

# Service for managing user currency preferences
class CurrencyPreferenceService
  def initialize(preference, context = {})
    @preference = preference
    @context = context
  end

  # Update user currency preference
  # @param new_currency_id [Integer] new currency ID
  def update_preference(new_currency_id)
    validate_currency(new_currency_id)

    @preference.currency_id = new_currency_id
    @preference.save!

    # Invalidate cache or trigger events if needed
    # For example, trigger background job or event
    Rails.logger.info("Currency preference updated for user #{@preference.user_id} to currency #{new_currency_id}")
  end

  # Validate preference change
  # @param new_currency [Currency] new currency
  def validate_preference_change(new_currency)
    unless new_currency.active?
      raise ArgumentError, "Currency must be active"
    end

    unless new_currency.supported?
      raise ArgumentError, "Currency must be supported"
    end
  end

  private

  # Validate currency exists and is valid
  # @param currency_id [Integer] currency ID
  def validate_currency(currency_id)
    currency = Currency.find_by(id: currency_id)
    raise ArgumentError, "Currency not found" unless currency

    validate_preference_change(currency)
  end
end