# frozen_string_literal: true

# Domain Events for User Currency Preference
module UserCurrencyPreferenceEvents
  # Event fired when user currency preference is created
  class UserCurrencyPreferenceCreatedEvent < DomainEvents::DomainEvent
    immutable_struct fields: [
      :event_id, :aggregate_id, :event_type, :occurred_at, :recorded_at,
      :correlation_id, :causation_id, :metadata, :version,
      :user_id, :currency_id, :previous_currency_id
    ]

    def event_type
      'user_currency_preference_created'
    end

    def event_data
      {
        user_id: user_id,
        currency_id: currency_id,
        previous_currency_id: previous_currency_id
      }
    end
  end

  # Event fired when user currency preference is updated
  class UserCurrencyPreferenceUpdatedEvent < DomainEvents::DomainEvent
    immutable_struct fields: [
      :event_id, :aggregate_id, :event_type, :occurred_at, :recorded_at,
      :correlation_id, :causation_id, :metadata, :version,
      :user_id, :currency_id, :previous_currency_id
    ]

    def event_type
      'user_currency_preference_updated'
    end

    def event_data
      {
        user_id: user_id,
        currency_id: currency_id,
        previous_currency_id: previous_currency_id
      }
    end
  end

  # Event factory for creating user currency preference events
  class EventFactory
    def self.preference_created(aggregate_id, user_id, currency_id, previous_currency_id = nil)
      UserCurrencyPreferenceCreatedEvent.new(
        aggregate_id: aggregate_id,
        user_id: user_id,
        currency_id: currency_id,
        previous_currency_id: previous_currency_id
      )
    end

    def self.preference_updated(aggregate_id, user_id, currency_id, previous_currency_id)
      UserCurrencyPreferenceUpdatedEvent.new(
        aggregate_id: aggregate_id,
        user_id: user_id,
        currency_id: currency_id,
        previous_currency_id: previous_currency_id
      )
    end
  end
end