# frozen_string_literal: true

# GamificationEvents - Event Sourcing for Spin-to-Win Operations
#
# Implements sophisticated event sourcing for gamification features following the Prime Mandate:
# - Hermetic Decoupling: Isolated event logic from business processes
# - Asymptotic Optimality: Optimized event storage and retrieval
# - Architectural Zenith: Designed for horizontal scalability and CQRS patterns
# - Antifragility Postulate: Immutable audit trails for regulatory compliance

module GamificationEvents
  # Base event class with common functionality
  class BaseEvent
    attr_reader :aggregate_id, :event_id, :event_type, :event_data, :metadata, :timestamp, :version

    def initialize(aggregate_id, event_data = {}, metadata = {})
      @aggregate_id = aggregate_id
      @event_id = SecureRandom.uuid
      @event_type = self.class.name.demodulize.underscore
      @event_data = event_data
      @metadata = metadata.merge(
        user_agent: extract_user_agent,
        ip_address: extract_ip_address,
        session_id: extract_session_id,
        request_id: extract_request_id,
        compliance_flags: extract_compliance_flags,
        security_context: extract_security_context
      )
      @timestamp = Time.current
      @version = 1
    end

    def to_h
      {
        event_id: event_id,
        aggregate_id: aggregate_id,
        event_type: event_type,
        event_data: event_data,
        metadata: metadata,
        timestamp: timestamp,
        version: version,
        checksum: calculate_checksum,
        compliance_hash: calculate_compliance_hash
      }
    end

    def to_json
      JSON.generate(to_h)
    end

    private

    def calculate_checksum
      Digest::SHA256.hexdigest("#{event_id}:#{aggregate_id}:#{event_data.to_json}:#{timestamp}")
    end

    def calculate_compliance_hash
      Digest::SHA384.hexdigest("#{event_id}:#{aggregate_id}:#{event_data.to_json}:#{timestamp}:#{Rails.application.secret_key_base}")
    end

    def extract_user_agent
      nil
    end

    def extract_ip_address
      nil
    end

    def extract_session_id
      nil
    end

    def extract_request_id
      nil
    end

    def extract_compliance_flags
      {
        gdpr_applicable: true,
        ccpa_applicable: false,
        lgpd_applicable: false,
        pipeda_applicable: false,
        audit_required: true,
        retention_period: 7.years
      }
    end

    def extract_security_context
      {
        encryption_level: :aes256,
        access_level: :restricted,
        classification: :sensitive,
        handling_requirements: [:encrypt_at_rest, :audit_access, :secure_transmission]
      }
    end
  end

  # Spin-to-Win Events
  class SpinOccurredEvent < BaseEvent
    def initialize(spin_to_win, user, prize, spin_data = {})
      super(spin_to_win.id, {
        user_id: user.id,
        prize_id: prize.id,
        prize_name: prize.prize_name,
        prize_type: prize.prize_type,
        prize_value: prize.prize_value,
        spin_to_win_id: spin_to_win.id,
        spin_to_win_name: spin_to_win.name,
        spun_at: Time.current,
        remaining_spins: spin_data[:remaining_spins],
        spin_outcome: spin_data[:outcome] || 'success'
      }, {
        event_category: :gamification,
        business_impact: :low,
        compliance_level: :standard,
        retention_category: :medium_term
      })
    end
  end

  class PrizeAwardedEvent < BaseEvent
    def initialize(user, prize, award_data = {})
      super(user.id, {
        prize_id: prize.id,
        prize_name: prize.prize_name,
        prize_type: prize.prize_type,
        prize_value: prize.prize_value,
        award_method: award_data[:method] || 'spin_to_win',
        user_balance_before: award_data[:balance_before],
        user_balance_after: award_data[:balance_after],
        award_timestamp: Time.current
      }, {
        event_category: :gamification,
        business_impact: :low,
        compliance_level: :standard,
        retention_category: :medium_term
      })
    end
  end

  # Event Store for Gamification Events
  class EventStore
    class << self
      def append(event)
        event_record = EventRecord.create!(
          event_id: event.event_id,
          aggregate_id: event.aggregate_id,
          event_type: event.event_type,
          event_data: event.event_data,
          metadata: event.metadata,
          timestamp: event.timestamp,
          version: event.version,
          checksum: event.send(:calculate_checksum),
          compliance_hash: event.send(:calculate_compliance_hash)
        )

        publish_to_event_stream(event)
        event_record
      end

      def find_events_for_aggregate(aggregate_id, event_types = nil)
        query = EventRecord.where(aggregate_id: aggregate_id)
        query = query.where(event_type: event_types) if event_types.present?
        query.order(:timestamp)
      end

      private

      def publish_to_event_stream(event)
        # Publish to event stream for real-time processing
        EventStreamPublisher.publish(event)
      end
    end
  end

  # Event Record Model
  class EventRecord < ApplicationRecord
    self.table_name = 'gamification_event_records'

    validates :event_id, :aggregate_id, :event_type, presence: true
    validates :checksum, :compliance_hash, presence: true

    encrypts :event_data, :metadata
  end

  # Event Stream Publisher
  class EventStreamPublisher
    class << self
      def publish(event)
        # Publish to Redis for real-time consumption
        Redis.current.xadd(
          'gamification_events',
          {
            event_id: event.event_id,
            aggregate_id: event.aggregate_id,
            event_type: event.event_type,
            timestamp: event.timestamp.to_i
          },
          id: event.event_id,
          maxlen: 100000
        )
      end
    end
  end
end