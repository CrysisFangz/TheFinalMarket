# frozen_string_literal: true

# Event Store Infrastructure
# High-performance event storage with snapshotting and projections
class EventStore
  include Singleton

  def initialize
    @event_storage = Rails.configuration.event_store || ActiveRecordEventStore.new
  end

  # Append events to aggregate stream
  def append_events(aggregate_id, events)
    CircuitBreaker.execute_with_fallback(:event_storage) do
      events.each do |event|
        store_event(aggregate_id, event)
      end

      # Update snapshot if needed
      update_snapshot_if_needed(aggregate_id, events)

      # Trigger projections
      trigger_projections(aggregate_id, events)

      true
    end
  rescue => e
    Rails.logger.error("Failed to append events for aggregate #{aggregate_id}: #{e.message}")
    raise EventStorageError, "Event storage failed: #{e.message}"
  end

  # Load events for aggregate
  def load_events(aggregate_id, from_version: 0)
    CircuitBreaker.execute_with_fallback(:event_loading) do
      # Try to load from snapshot first
      snapshot = load_snapshot(aggregate_id)
      return snapshot.events_since(from_version) if snapshot && snapshot.version >= from_version

      # Load from event storage
      @event_storage.load_events(aggregate_id, from_version)
    end
  end

  # Load events for multiple aggregates
  def load_events_batch(aggregate_ids, from_version: 0)
    CircuitBreaker.execute_with_fallback(:batch_event_loading) do
      # Optimize for batch loading
      ReactiveParallelExecutor.execute do
        aggregate_ids.map do |aggregate_id|
          [aggregate_id, load_events(aggregate_id, from_version: from_version)]
        end.to_h
      end
    end
  end

  private

  def store_event(aggregate_id, event)
    event_data = {
      aggregate_id: aggregate_id,
      event_id: event.event_id,
      event_type: event.event_type,
      aggregate_type: event.aggregate_type,
      event_version: event.event_version,
      occurred_at: event.occurred_at,
      correlation_id: event.correlation_id,
      causation_id: event.causation_id,
      event_data: event.to_h,
      metadata: event.metadata
    }

    @event_storage.store_event(event_data)
  end

  def update_snapshot_if_needed(aggregate_id, events)
    # Update snapshot every 100 events or based on time
    snapshot_threshold = 100
    recent_events_count = @event_storage.count_events_since_snapshot(aggregate_id)

    if recent_events_count >= snapshot_threshold
      create_snapshot(aggregate_id)
    end
  end

  def create_snapshot(aggregate_id)
    events = load_events(aggregate_id)
    snapshot = EventSnapshot.new(aggregate_id, events)

    @event_storage.store_snapshot(snapshot)
  end

  def load_snapshot(aggregate_id)
    @event_storage.load_snapshot(aggregate_id)
  end

  def trigger_projections(aggregate_id, events)
    # Trigger async projection updates
    events.each do |event|
      ProjectionUpdateJob.perform_async(aggregate_id, event.event_type, event.to_h)
    end
  end
end

# Supporting classes
class EventStorageError < StandardError; end

class EventSnapshot
  attr_reader :aggregate_id, :version, :snapshot_data, :created_at

  def initialize(aggregate_id, events)
    @aggregate_id = aggregate_id
    @version = events.last&.event_id
    @snapshot_data = build_snapshot_data(events)
    @created_at = Time.current
  end

  def events_since(from_version)
    # Return events after the snapshot version
    # Implementation would filter events based on version
    []
  end

  private

  def build_snapshot_data(events)
    # Build snapshot data from events
    # Implementation would aggregate event data into snapshot
    {}
  end
end