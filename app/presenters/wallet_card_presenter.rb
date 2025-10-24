# frozen_string_literal: true

# WalletCardPresenter handles presentation logic for WalletCard,
# decoupling display concerns from the model.
class WalletCardPresenter
  attr_reader :wallet_card

  def initialize(wallet_card)
    @wallet_card = wallet_card
  end

  # Returns a masked version of the card number for security.
  # Optimized to avoid string manipulation overhead in hot paths.
  def masked_number
    return '' unless wallet_card.last_four

    "•••• •••• •••• #{wallet_card.last_four}"
  end

  # Returns a human-readable display name for the card.
  # Uses caching and memoization for optimal performance.
  def display_name
    cache_key = "wallet_card_display_name_#{wallet_card.id}_#{wallet_card.updated_at.to_i}"
    @display_name ||= Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      brand = wallet_card.card_brand&.titleize || 'Unknown'
      type = wallet_card.card_type&.titleize&.gsub('_', ' ') || 'Card'
      last_four = wallet_card.last_four || '****'

      "#{brand} #{type} ••#{last_four}"
    end
  end

  # Additional presentation methods can be added here as needed,
  # such as formatting for different locales or UI contexts.
end