# frozen_string_literal: true

# Domain Events for Event Sourcing Architecture
#
# This module defines all domain events for the Channel Interaction domain, implementing
# event sourcing patterns for complete audit trails, state reconstruction, and temporal
# queries. Each event represents an immutable fact that has occurred in the domain.
#
# Key Principles:
# - Events are immutable facts that have already happened
# - Events are the single source of truth for system state
# - Events enable temporal queries and "time travel"
# - Events support CQRS separation of concerns
# - Events enable distributed system integration
#
# @see InteractionInitiatedEvent
# @see InteractionProcessedEvent
# @see DomainEvent
module DomainEvents
  # Base class for all domain events
  # Provides common event infrastructure and serialization
  class DomainEvent
    include Comparable
    include Concurrent::ImmutableStruct

    # Common fields for all domain events
    fields = [
      :event_id,        # Unique event identifier (UUID)
      :aggregate_id,    # ID of the aggregate that produced this event
      :event_type,      # Type of event (for serialization)
      :occurred_at,     # When the event actually occurred
      :recorded_at,     # When the event was recorded in the store
      :correlation_id,  # Distributed tracing correlation ID
      :causation_id,    # ID of the event that caused this event
      :metadata,        # Additional event metadata (frozen)
      :version         # Event version for optimistic concurrency
    ]

    immutable_struct fields: fields, validate: true

    # Initialize with defaults and validation
    def initialize(attributes = {})
      # Set default timestamps
      attributes = attributes.with_defaults(
        event_id: generate_event_id,
        occurred_at: Time.current,
        recorded_at: Time.current,
        correlation_id: generate_correlation_id,
        metadata: {},
        version: 1
      )

      # Deep freeze metadata
      attributes[:metadata] = deep_freeze(attributes[:metadata])

      # Validate required fields
      validate_required_fields!(attributes)

      super(attributes)
    end

    # Equality based on event content
    def ==(other)
      return false unless other.is_a?(DomainEvent)

      event_id == other.event_id &&
      aggregate_id == other.aggregate_id &&
      event_type == other.event_type &&
      occurred_at == other.occurred_at
    end

    # Hash for collections
    def hash
      [event_id, aggregate_id, event_type, occurred_at].hash
    end

    # Comparable by occurrence time
    def <=>(other)
      return nil unless other.is_a?(DomainEvent)
      occurred_at <=> other.occurred_at
    end

    # Convert to serializable hash
    def to_hash
      {
        event_id: event_id,
        aggregate_id: aggregate_id,
        event_type: event_type,
        occurred_at: occurred_at,
        recorded_at: recorded_at,
        correlation_id: correlation_id,
        causation_id: causation_id,
        metadata: metadata,
        version: version,
        event_data: event_data
      }
    end

    # Convert to JSON for storage/publishing
    def to_json(**options)
      to_hash.merge(event_data: event_data).to_json(options)
    end

    # Event-specific data (to be implemented by subclasses)
    def event_data
      raise NotImplementedError, 'Subclasses must implement event_data'
    end

    private

    def generate_event_id
      "evt_#{SecureRandom.uuid}"
    end

    def generate_correlation_id
      Thread.current[:correlation_id] || "corr_#{SecureRandom.uuid}"
    end

    def deep_freeze(obj)
      case obj
      when Hash
        obj.each_value { |value| deep_freeze(value) }
        obj.freeze
      when Array
        obj.each { |item| deep_freeze(item) }
        obj.freeze
      else
        obj.freeze if obj.respond_to?(:freeze)
      end
      obj
    end

    def validate_required_fields!(attributes)
      required = [:event_id, :aggregate_id, :event_type, :occurred_at]
      missing = required.select { |field| attributes[field].nil? }

      unless missing.empty?
        raise ArgumentError, "Missing required fields: #{missing.join(', ')}"
      end
    end
  end

  # Event fired when a new interaction is initiated
  class InteractionInitiatedEvent < DomainEvent
    immutable_struct fields: [
      :event_id, :aggregate_id, :event_type, :occurred_at, :recorded_at,
      :correlation_id, :causation_id, :metadata, :version,
      :customer_id,      # Customer who initiated the interaction
      :channel_id,       # Channel where interaction occurred
      :interaction_type, # Type of interaction (enum)
      :interaction_data, # Raw interaction payload
      :user_agent,       # Client user agent string
      :ip_address,       # Client IP address
      :session_id        # Session identifier
    ]

    def event_type
      'interaction_initiated'
    end

    def event_data
      {
        customer_id: customer_id,
        channel_id: channel_id,
        interaction_type: interaction_type,
        interaction_data: interaction_data,
        user_agent: user_agent,
        ip_address: ip_address,
        session_id: session_id
      }
    end
  end

  # Event fired when interaction processing completes
  class InteractionProcessedEvent < DomainEvent
    immutable_struct fields: [
      :event_id, :aggregate_id, :event_type, :occurred_at, :recorded_at,
      :correlation_id, :causation_id, :metadata, :version,
      :processing_time_ms,  # Time taken to process
      :value_score,         # Calculated business value
      :context_data,        # Enriched context information
      :processor_version    # Version of processing engine used
    ]

    def event_type
      'interaction_processed'
    end

    def event_data
      {
        processing_time_ms: processing_time_ms,
        value_score: value_score,
        context_data: context_data,
        processor_version: processor_version
      }
    end
  end

  # Event fired when interaction value is recalculated
  class InteractionValueRecalculatedEvent < DomainEvent
    immutable_struct fields: [
      :event_id, :aggregate_id, :event_type, :occurred_at, :recorded_at,
      :correlation_id, :causation_id, :metadata, :version,
      :old_value_score,    # Previous value score
      :new_value_score,    # Updated value score
      :recalculation_reason, # Why recalculation was triggered
      :algorithm_version   # Version of algorithm used
    ]

    def event_type
      'interaction_value_recalculated'
    end

    def event_data
      {
        old_value_score: old_value_score,
        new_value_score: new_value_score,
        recalculation_reason: recalculation_reason,
        algorithm_version: algorithm_version
      }
    end
  end

  # Event fired when interaction context is enriched
  class InteractionContextEnrichedEvent < DomainEvent
    immutable_struct fields: [
      :event_id, :aggregate_id, :event_type, :occurred_at, :recorded_at,
      :correlation_id, :causation_id, :metadata, :version,
      :original_context,    # Context before enrichment
      :enriched_context,    # Context after enrichment
      :enrichment_source,   # Source of enrichment data
      :enrichment_version   # Version of enrichment service
    ]

    def event_type
      'interaction_context_enriched'
    end

    def event_data
      {
        original_context: original_context,
        enriched_context: enriched_context,
        enrichment_source: enrichment_source,
        enrichment_version: enrichment_version
      }
    end
  end

  # Event fired when interaction is archived
  class InteractionArchivedEvent < DomainEvent
    immutable_struct fields: [
      :event_id, :aggregate_id, :event_type, :occurred_at, :recorded_at,
      :correlation_id, :causation_id, :metadata, :version,
      :archive_reason,      # Reason for archiving
      :archived_by,         # Who initiated archiving
      :retention_period_days # How long to retain
    ]

    def event_type
      'interaction_archived'
    end

    def event_data
      {
        archive_reason: archive_reason,
        archived_by: archived_by,
        retention_period_days: retention_period_days
      }
    end
  end

  # Event fired when interaction is flagged for review
  class InteractionFlaggedEvent < DomainEvent
    immutable_struct fields: [
      :event_id, :aggregate_id, :event_type, :occurred_at, :recorded_at,
      :correlation_id, :causation_id, :metadata, :version,
      :flag_reason,         # Reason for flagging
      :confidence_score,    # Confidence in the flag (0.0-1.0)
      :flagged_by,          # Who or what flagged the interaction
      :review_priority      # Priority level for review (low/medium/high)
    ]

    def event_type
      'interaction_flagged'
    end

    def event_data
      {
        flag_reason: flag_reason,
        confidence_score: confidence_score,
        flagged_by: flagged_by,
        review_priority: review_priority
      }
    end
  end

  # Event factory for creating domain events
  class EventFactory
    # Create interaction initiated event
    def self.interaction_initiated(aggregate_id, attributes = {})
      InteractionInitiatedEvent.new(
        aggregate_id: aggregate_id,
        **attributes
      )
    end

    # Create interaction processed event
    def self.interaction_processed(aggregate_id, attributes = {})
      InteractionProcessedEvent.new(
        aggregate_id: aggregate_id,
        **attributes
      )
    end

    # Create value recalculated event
    def self.value_recalculated(aggregate_id, old_score, new_score, reason)
      InteractionValueRecalculatedEvent.new(
        aggregate_id: aggregate_id,
        old_value_score: old_score,
        new_value_score: new_score,
        recalculation_reason: reason
      )
    end

    # Create context enriched event
    def self.context_enriched(aggregate_id, original_context, enriched_context, source)
      InteractionContextEnrichedEvent.new(
        aggregate_id: aggregate_id,
        original_context: original_context,
        enriched_context: enriched_context,
        enrichment_source: source
      )
    end

    # Create interaction archived event
    def self.interaction_archived(aggregate_id, reason, archived_by, retention_days)
      InteractionArchivedEvent.new(
        aggregate_id: aggregate_id,
        archive_reason: reason,
        archived_by: archived_by,
        retention_period_days: retention_days
      )
    end

    # Create interaction flagged event
    def self.interaction_flagged(aggregate_id, reason, confidence, flagged_by, priority)
      InteractionFlaggedEvent.new(
        aggregate_id: aggregate_id,
        flag_reason: reason,
        confidence_score: confidence,
        flagged_by: flagged_by,
        review_priority: priority
      )
    end
  end
end