# frozen_string_literal: true

# WalletCardService handles business logic for WalletCard operations,
# ensuring separation of concerns, optimal performance, and resilience.
class WalletCardService
  include ActiveModel::Validations

  attr_reader :wallet_card

  def initialize(wallet_card)
    @wallet_card = wallet_card
    @circuit_breaker = WalletCardCircuitBreaker.new
    validate_wallet_card
  end

  # Sets the wallet card as the default for the mobile wallet.
  # Optimizes by updating only the necessary records and using database constraints.
  def set_as_default!
    return false unless valid?

    @circuit_breaker.call do
      # Use a transaction for atomicity and to prevent race conditions
      ActiveRecord::Base.transaction do
        # Reset all other cards in the wallet to non-default
        wallet_card.mobile_wallet.wallet_cards.where.not(id: wallet_card.id).update_all(is_default: false)
        # Set this card as default
        wallet_card.update!(is_default: true)
        # Publish event for audit
        event = WalletCardSetAsDefaultEvent.new(wallet_card)
        event.publish
      end
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  # Checks if the card is expired based on expiry date.
  # Optimized to avoid unnecessary object creation.
  def expired?
    return false unless wallet_card.expiry_month && wallet_card.expiry_year

    # Calculate expiry date efficiently
    expiry_date = Date.new(wallet_card.expiry_year, wallet_card.expiry_month, -1)
    expiry_date < Date.current
  end

  # Removes the wallet card by updating its status and timestamp.
  # Includes audit trail for state changes.
  def remove!
    return false unless valid?

    ActiveRecord::Base.transaction do
      wallet_card.update!(status: :removed, removed_at: Time.current)
      # Optionally, trigger an event for audit (e.g., using Wisper or similar)
      publish_removal_event
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  # Validates the wallet card instance.
  def valid?
    wallet_card.present? && wallet_card.persisted?
  end

  private

  def validate_wallet_card
    errors.add(:wallet_card, 'must be present and persisted') unless valid?
  end

  def publish_removal_event
    # Placeholder for event publishing, e.g., using a gem like Wisper
    # Event could be used for audit logs or notifications
    # Example: Wisper.publish(:wallet_card_removed, wallet_card)
  end
end