# frozen_string_literal: true

require_relative 'state'

# ═══════════════════════════════════════════════════════════════════════════════════
# EVENT SOURCING INFRASTRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════════

# Immutable event store for bond transaction events
class BondTransactionEventStore
  class << self
    def append_event(event)
      # Store event in immutable event store
      event_record = BondTransactionEvent.create!(
        event_id: event[:event_id],
        event_type: event[:event_type],
        aggregate_id: event[:aggregate_id],
        aggregate_type: event[:aggregate_type],
        event_data: event[:event_data],
        metadata: event[:metadata],
        created_at: event[:metadata][:timestamp]
      )

      # Publish to event bus for reactive processing
      EventBus.publish("bond_transaction_#{event[:event_type].underscore}", event)

      # Cache event for performance
      cache_event(event)

      event_record
    end

    def load_events(aggregate_id)
      # Load all events for aggregate with optimized query
      Rails.cache.fetch("bond_transaction_events_#{aggregate_id}", expires_in: 1.hour) do
        BondTransactionEvent.where(aggregate_id: aggregate_id)
                          .order(:created_at)
                          .map(&:to_event)
      end
    end

    def load_events_since(timestamp, event_types = nil)
      # Load events since timestamp with optional filtering
      query = BondTransactionEvent.where('created_at >= ?', timestamp)
      query = query.where(event_type: event_types) if event_types.present?

      query.order(:created_at).map(&:to_event)
    end

    private

    def cache_event(event)
      Rails.cache.write(
        "bond_transaction_event_#{event[:event_id]}",
        event,
        expires_in: 24.hours
      )
    end
  end
end

# Event record for immutable storage
class BondTransactionEvent < ApplicationRecord
  self.table_name = 'bond_transaction_events'

  serialize :event_data, JSON
  serialize :metadata, JSON

  validates :event_id, :event_type, :aggregate_id, :aggregate_type, presence: true
  validates :event_id, uniqueness: true

  def to_event
    {
      event_id: event_id,
      event_type: event_type,
      aggregate_id: aggregate_id,
      aggregate_type: aggregate_type,
      event_data: event_data,
      metadata: metadata
    }
  end
end