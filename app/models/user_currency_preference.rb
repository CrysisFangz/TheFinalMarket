# UserCurrencyPreference Model - Enterprise-Grade Implementation
#
# This model represents a user's preferred currency, serving as a join table
# between User and Currency models. It adheres to the Prime Mandate principles:
#
# - Epistemic Mandate: Self-elucidating structure with clear associations and validations.
# - Chronometric Mandate: Optimized queries with scopes to prevent N+1 issues.
# - Architectural Zenith: Scalable design supporting high-load scenarios.
# - Antifragility Postulate: Robust validations ensuring data integrity.
#
# The model enforces a one-to-one relationship between users and their currency preferences,
# with built-in uniqueness constraints and referential integrity.

class UserCurrencyPreference < ApplicationRecord
  # Associations - Core relationships with foreign key constraints
  belongs_to :user, inverse_of: :user_currency_preference
  belongs_to :currency, inverse_of: :user_currency_preferences

  # Validations - Enterprise-grade constraints for data integrity
  validates :user_id, presence: true, uniqueness: true
  validates :currency_id, presence: true

  # Scopes - Optimized query patterns for performance
  scope :for_active_currencies, -> {
    joins(:currency).where(currencies: { active: true })
  }

  scope :by_currency_code, ->(code) {
    joins(:currency).where(currencies: { code: code })
  }

  # Instance Methods - Utility functions for preference management

  # Returns the associated currency object
  def preferred_currency
    currency
  end

  # Updates the user's currency preference
  # @param new_currency [Currency] The new currency to set as preference
  # @return [Boolean] Success status of the update
  def update_preference(new_currency)
    update(currency: new_currency)
  end

  # Checks if the preference is for an active currency
  # @return [Boolean] True if the associated currency is active
  def active_preference?
    currency&.active?
  end
end