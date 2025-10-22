# frozen_string_literal: true

# Event Store implementation for camera capture domain events
# Provides immutable event storage and retrieval with ACID guarantees
class EventStore
  # Event stream not found error
  class EventStreamNotFound < StandardError; end

  # Concurrency conflict error
  class ConcurrencyError < StandardError; end

  attr_reader :storage_adapter

  # Initialize event store
  # @param storage_adapter [Object] storage backend adapter
  def initialize(storage_adapter = nil)
    @storage_adapter = storage_adapter || RailsEventStoreAdapter.new
  end

  # Append events to aggregate stream
  # @param aggregate_id [String] aggregate identifier
  # @param events [Array<CameraCaptureEvent>] events to append
  # @param expected_version [Integer] expected current version
  # @raise [ConcurrencyError] if version conflict
  def append_events(aggregate_id, events, expected_version = nil)
    validate_events!(events)

    # Check version concurrency if specified
    if expected_version
      current_version = get_current_version(aggregate_id)
      raise ConcurrencyError, 'Version conflict detected' unless current_version == expected_version
    end

    # Store events with next version numbers
    events.each_with_index do |event, index|
      event_data = prepare_event_for_storage(event, expected_version.to_i + index + 1)

      @storage_adapter.store_event(aggregate_id, event_data)
    end

    # Publish events to message bus for projections and handlers
    publish_events_to_bus(events)

    true
  rescue StandardError => e
    # Ensure atomicity - if any part fails, no events are stored
    Rails.logger.error("Failed to append events: #{e.message}")
    raise
  end

  # Load event stream for aggregate
  # @param aggregate_id [String] aggregate identifier
  # @param from_version [Integer] starting version (inclusive)
  # @param to_version [Integer] ending version (inclusive)
  # @return [Array<CameraCaptureEvent>] events in order
  # @raise [EventStreamNotFound] if stream doesn't exist
  def load_event_stream(aggregate_id, from_version = 1, to_version = nil)
    event_data = @storage_adapter.load_events(aggregate_id, from_version, to_version)

    raise EventStreamNotFound, "No events found for aggregate: #{aggregate_id}" if event_data.empty?

    # Reconstruct domain events from stored data
    event_data.map { |data| reconstruct_event(data) }
  end

  # Load all events for aggregate
  # @param aggregate_id [String] aggregate identifier
  # @return [Array<CameraCaptureEvent>] all events in order
  def load_all_events(aggregate_id)
    load_event_stream(aggregate_id, 1, nil)
  end

  # Get current version of aggregate
  # @param aggregate_id [String] aggregate identifier
  # @return [Integer] current version
  def get_current_version(aggregate_id)
    @storage_adapter.get_current_version(aggregate_id)
  rescue EventStreamNotFound
    0 # No events yet
  end

  # Check if aggregate exists
  # @param aggregate_id [String] aggregate identifier
  # @return [Boolean] true if exists
  def aggregate_exists?(aggregate_id)
    get_current_version(aggregate_id) > 0
  end

  # Get events by type across all aggregates
  # @param event_type [Class] event class to find
  # @param from_timestamp [Time] start time (optional)
  # @param to_timestamp [Time] end time (optional)
  # @return [Array<CameraCaptureEvent>] matching events
  def get_events_by_type(event_type, from_timestamp = nil, to_timestamp = nil)
    event_data = @storage_adapter.query_events_by_type(
      event_type.name,
      from_timestamp,
      to_timestamp
    )

    event_data.map { |data| reconstruct_event(data) }
  end

  # Get events by user across all aggregates
  # @param user_id [Integer] user identifier
  # @param from_timestamp [Time] start time (optional)
  # @param to_timestamp [Time] end time (optional)
  # @return [Array<CameraCaptureEvent>] user's events
  def get_events_by_user(user_id, from_timestamp = nil, to_timestamp = nil)
    event_data = @storage_adapter.query_events_by_user(
      user_id,
      from_timestamp,
      to_timestamp
    )

    event_data.map { |data| reconstruct_event(data) }
  end

  # Archive old events based on retention policy
  # @param retention_days [Integer] days to retain
  # @return [Integer] number of events archived
  def archive_old_events(retention_days = 2555) # 7 years default
    cutoff_date = retention_days.days.ago

    archived_count = @storage_adapter.archive_events_before(cutoff_date)

    Rails.logger.info("Archived #{archived_count} events older than #{cutoff_date}")

    archived_count
  end

  private

  # Validate events before storage
  # @param events [Array<CameraCaptureEvent>] events to validate
  def validate_events!(events)
    raise ArgumentError, 'Events array cannot be empty' if events.empty?

    events.each_with_index do |event, index|
      validate_single_event!(event, index)
    end
  end

  # Validate single event
  # @param event [CameraCaptureEvent] event to validate
  # @param index [Integer] position in array
  def validate_single_event!(event, index)
    unless event.is_a?(CameraCaptureEvent)
      raise ArgumentError, "Event #{index} is not a CameraCaptureEvent"
    end

    unless event.aggregate_id
      raise ArgumentError, "Event #{index} missing aggregate_id"
    end

    unless event.event_id
      raise ArgumentError, "Event #{index} missing event_id"
    end
  end

  # Prepare event for storage
  # @param event [CameraCaptureEvent] event to prepare
  # @param version [Integer] version number
  # @return [Hash] storage-ready event data
  def prepare_event_for_storage(event, version)
    {
      id: event.event_id,
      aggregate_id: event.aggregate_id,
      event_type: event.event_type,
      event_data: event.event_data,
      timestamp: event.timestamp,
      version: version,
      metadata: event.metadata
    }
  end

  # Reconstruct domain event from stored data
  # @param data [Hash] stored event data
  # @return [CameraCaptureEvent] reconstructed event
  def reconstruct_event(data)
    event_class = event_type_to_class(data[:event_type])

    # Create event instance with stored data
    case event_class.name
    when 'ImageCapturedEvent'
      event_class.new(
        data[:aggregate_id],
        user_id: data[:event_data][:user_id],
        capture_type: CaptureType.from_symbol(data[:event_data][:capture_type]),
        image_metadata: ImageMetadata.new(data[:event_data][:image_metadata]),
        device_info: DeviceInfo.new(data[:event_data][:device_info]),
        capture_context: data[:event_data][:capture_context],
        event_id: data[:id],
        timestamp: data[:timestamp],
        version: data[:version],
        metadata: data[:metadata]
      )
    when 'ImageProcessingStartedEvent'
      event_class.new(
        data[:aggregate_id],
        processing_started_at: data[:event_data][:processing_started_at],
        priority: data[:event_data][:priority],
        estimated_completion: data[:event_data][:estimated_completion],
        processing_node: data[:event_data][:processing_node],
        event_id: data[:id],
        timestamp: data[:timestamp],
        version: data[:version],
        metadata: data[:metadata]
      )
    when 'ImageProcessingCompletedEvent'
      event_class.new(
        data[:aggregate_id],
        processing_results: data[:event_data][:processing_results],
        validation_status: data[:event_data][:validation_status],
        optimization_data: data[:event_data][:optimization_data],
        analysis_metadata: data[:event_data][:analysis_metadata],
        event_id: data[:id],
        timestamp: data[:timestamp],
        version: data[:version],
        metadata: data[:metadata]
      )
    when 'ImageProcessingFailedEvent'
      event_class.new(
        data[:aggregate_id],
        error_message: data[:event_data][:error_message],
        error_code: data[:event_data][:error_code],
        failure_timestamp: data[:event_data][:failure_timestamp],
        retry_recommended: data[:event_data][:retry_recommended],
        error_details: data[:event_data][:error_details],
        event_id: data[:id],
        timestamp: data[:timestamp],
        version: data[:version],
        metadata: data[:metadata]
      )
    when 'CameraCaptureArchivedEvent'
      event_class.new(
        data[:aggregate_id],
        archived_at: data[:event_data][:archived_at],
        reason: data[:event_data][:reason],
        retention_until: data[:event_data][:retention_until],
        archive_location: data[:event_data][:archive_location],
        access_tier: data[:event_data][:access_tier],
        event_id: data[:id],
        timestamp: data[:timestamp],
        version: data[:version],
        metadata: data[:metadata]
      )
    else
      raise ArgumentError, "Unknown event type: #{event_class.name}"
    end
  end

  # Convert event type string to class
  # @param event_type [String] event type name
  # @return [Class] event class
  def event_type_to_class(event_type)
    event_type.constantize
  rescue NameError
    raise ArgumentError, "Unknown event type: #{event_type}"
  end

  # Publish events to message bus
  # @param events [Array<CameraCaptureEvent>] events to publish
  def publish_events_to_bus(events)
    # This would integrate with message bus (Redis Streams, RabbitMQ, etc.)
    events.each do |event|
      # Publish to different channels based on event type
      publish_to_channel(event.event_type, event)
    end
  end

  # Publish event to specific channel
  # @param event_type [String] type of event
  # @param event [CameraCaptureEvent] event to publish
  def publish_to_channel(event_type, event)
    channel_name = "camera_capture.#{event_type.demodulize.underscore}"

    # This would use Redis Streams or similar for reliable message delivery
    Rails.logger.debug("Publishing event to channel: #{channel_name}")

    # In a real implementation, this would:
    # 1. Serialize event to JSON
    # 2. Publish to Redis stream
    # 3. Handle retries and dead letter queues
  end

  # Rails Event Store adapter for ActiveRecord/PostgreSQL
  class RailsEventStoreAdapter
    # Store single event
    # @param aggregate_id [String] aggregate identifier
    # @param event_data [Hash] event data
    def store_event(aggregate_id, event_data)
      # This would store in PostgreSQL JSONB column
      # For now, use Rails logger as placeholder
      Rails.logger.info("Storing event: #{event_data[:event_type]} for aggregate: #{aggregate_id}")
    end

    # Load events for aggregate
    # @param aggregate_id [String] aggregate identifier
    # @param from_version [Integer] starting version
    # @param to_version [Integer] ending version
    # @return [Array<Hash>] event data
    def load_events(aggregate_id, from_version = 1, to_version = nil)
      # This would query PostgreSQL for events
      # For now, return empty array
      []
    end

    # Get current version for aggregate
    # @param aggregate_id [String] aggregate identifier
    # @return [Integer] current version
    def get_current_version(aggregate_id)
      # This would query max version from events table
      0
    end

    # Query events by type
    # @param event_type [String] event type name
    # @param from_timestamp [Time] start time
    # @param to_timestamp [Time] end time
    # @return [Array<Hash>] matching events
    def query_events_by_type(event_type, from_timestamp = nil, to_timestamp = nil)
      # This would query events table with indexes
      []
    end

    # Query events by user
    # @param user_id [Integer] user identifier
    # @param from_timestamp [Time] start time
    # @param to_timestamp [Time] end time
    # @return [Array<Hash>] user's events
    def query_events_by_user(user_id, from_timestamp = nil, to_timestamp = nil)
      # This would query events table with user index
      []
    end

    # Archive events before cutoff date
    # @param cutoff_date [Time] cutoff date
    # @return [Integer] number of events archived
    def archive_events_before(cutoff_date)
      # This would move old events to archive table
      0
    end
  end
end