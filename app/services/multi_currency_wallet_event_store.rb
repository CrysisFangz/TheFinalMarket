# MultiCurrencyWalletEventStore
# Handles event sourcing for wallet operations
class MultiCurrencyWalletEventStore
  def self.record_event(wallet, event_type, event_data)
    event = MultiCurrencyWalletActivity.create!(
      multi_currency_wallet: wallet,
      activity_type: event_type,
      details: event_data,
      occurred_at: Time.current
    )

    # Publish to event bus for async processing
    EventPublisher.publish('wallet_event', {
      wallet_id: wallet.id,
      event_type: event_type,
      event_data: event_data,
      timestamp: Time.current
    })

    event
  end

  def self.replay_events(wallet_id)
    events = MultiCurrencyWalletActivity.where(multi_currency_wallet_id: wallet_id).order(:occurred_at)

    events.each do |event|
      # Replay logic here
      yield event if block_given?
    end
  end
end