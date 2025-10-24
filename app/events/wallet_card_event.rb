# frozen_string_literal: true

# Base class for WalletCard events to support event sourcing and auditability.
# Events are immutable records of state changes for CQRS and audit trails.
class WalletCardEvent
  include ActiveModel::Model

  attr_accessor :wallet_card_id, :event_type, :data, :timestamp

  validates :wallet_card_id, :event_type, :timestamp, presence: true

  def initialize(attributes = {})
    super
    @timestamp ||= Time.current
  end

  # Publishes the event, e.g., to a message queue or event store.
  def publish
    # Placeholder for publishing logic, e.g., using a gem like Wisper or RabbitMQ
    # Example: Wisper.publish(event_type, self)
    # For now, log or store in a simple event log
    Rails.logger.info("WalletCard Event: #{event_type} for ID #{wallet_card_id} at #{timestamp}")
  end
end

# Specific event classes for different state changes
class WalletCardSetAsDefaultEvent < WalletCardEvent
  def initialize(wallet_card)
    super(
      wallet_card_id: wallet_card.id,
      event_type: 'set_as_default',
      data: { mobile_wallet_id: wallet_card.mobile_wallet_id, is_default: true }
    )
  end
end

class WalletCardRemovedEvent < WalletCardEvent
  def initialize(wallet_card)
    super(
      wallet_card_id: wallet_card.id,
      event_type: 'removed',
      data: { status: wallet_card.status, removed_at: wallet_card.removed_at }
    )
  end
end

class WalletCardExpiredEvent < WalletCardEvent
  def initialize(wallet_card)
    super(
      wallet_card_id: wallet_card.id,
      event_type: 'expired',
      data: { expiry_month: wallet_card.expiry_month, expiry_year: wallet_card.expiry_year }
    )
  end
end