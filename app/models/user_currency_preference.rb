# Enterprise-Grade User Currency Preference Model - Clean Architecture Implementation
#
# This model follows the Prime Mandate principles:
# - Single Responsibility: Pure data model with minimal business logic
# - Hermetic Decoupling: Isolated from service layer concerns
# - Asymptotic Optimality: Optimized for database performance
# - Architectural Zenith: Designed for horizontal scalability
# - Epistemic Mandate: Self-elucidating structure with clear associations
# - Chronometric Mandate: Optimized queries to prevent N+1 issues
# - Antifragility Postulate: Robust validations ensuring data integrity
#
# The UserCurrencyPreference model serves as a pure data access layer, delegating all
# business logic to appropriate service objects for maximum modularity
# and testability.

class UserCurrencyPreference < ApplicationRecord
  # Core associations - essential relationships only
  belongs_to :user, inverse_of: :user_currency_preference, null: false
  belongs_to :currency, inverse_of: :user_currency_preferences, null: false

  # Enhanced validations with enterprise-grade constraints
  validates :user_id, presence: true, uniqueness: true
  validates :currency_id, presence: true

  # Query scopes for performance optimization
  scope :active, -> { joins(:currency).where(currencies: { active: true }) }
  scope :supported, -> { joins(:currency).where(currencies: { supported: true }) }
  scope :by_currency_code, ->(code) { joins(:currency).where(currencies: { code: code }) }
  scope :for_active_currencies, -> { joins(:currency).where(currencies: { active: true }) }

  # ==================== SERVICE DELEGATION METHODS ====================

  # Currency Preference Management - Delegate to dedicated services
  def update_preference(new_currency_id, context = {})
    CurrencyPreferenceService.new(self, context).update_preference(new_currency_id)
  end

  def validate_preference_change(new_currency, context = {})
    CurrencyPreferenceService.new(self, context).validate_preference_change(new_currency)
  end

  # ==================== INSTANCE METHODS ====================

  # Utility methods for accessing currency details
  def currency_code
    currency&.code
  end

  def currency_name
    currency&.name
  end

  def currency_symbol
    currency&.symbol
  end

  # Returns the associated currency object
  def preferred_currency
    currency
  end

  # Checks if the preference is for an active currency
  # @return [Boolean] True if the associated currency is active
  def active_preference?
    currency&.active?
  end

  # ==================== PRIVATE METHODS ====================

  private

  # Ensure currency is active and supported before saving
  def validate_currency_status
    return unless currency

    unless currency.active?
      errors.add(:currency, "must be active")
    end

    unless currency.supported?
      errors.add(:currency, "must be supported")
    end
  end

  # Optimized callbacks - only essential data operations
  before_validation :validate_currency_status
end
