# frozen_string_literal: true

# Event store implementation for inventory domain events
# Provides persistence and retrieval of domain events with optimistic concurrency control
class InventoryEventStore
  EventRecord = Struct.new(:id, :aggregate_id, :event_type, :event_data, :version, :timestamp) do
    # Convert event record to domain event
    # @return [InventoryEvents::BaseEvent] reconstructed domain event
    def to_domain_event
      event_class = event_type.constantize
      event_class.new(aggregate_id, **event_data.symbolize_keys)
    end
  end

  # Append events to the event stream
  # @param aggregate_id [String] aggregate identifier
  # @param events [Array<InventoryEvents::BaseEvent>] events to append
  # @return [Boolean] true if append was successful
  def append_events(aggregate_id, events)
    return false if events.empty?

    ActiveRecord::Base.transaction do
      events.each_with_index do |event, index|
        version = current_version(aggregate_id) + index + 1

        # Create event record in database
        InventoryEventRecord.create!(
          aggregate_id: aggregate_id,
          event_type: event.class.name,
          event_data: event.to_h,
          version: version,
          timestamp: event.timestamp
        )

        # Update aggregate version in projections table if needed
        update_aggregate_projection(aggregate_id, version, event)
      end
    end

    true
  rescue ActiveRecord::RecordNotUnique => e
    # Handle concurrency conflicts
    Rails.logger.warn("Event store concurrency conflict for aggregate #{aggregate_id}: #{e.message}")
    false
  end

  # Get all events for an aggregate
  # @param aggregate_id [String] aggregate identifier
  # @return [Array<InventoryEvents::BaseEvent>] array of domain events
  def get_events_for_aggregate(aggregate_id)
    records = InventoryEventRecord.where(aggregate_id: aggregate_id).order(:version)

    records.map do |record|
      begin
        record.to_domain_event
      rescue => e
        Rails.logger.error("Failed to reconstruct event #{record.event_type} for aggregate #{aggregate_id}: #{e.message}")
        nil
      end
    end.compact
  end

  # Get events for an aggregate since a specific version
  # @param aggregate_id [String] aggregate identifier
  # @param since_version [Integer] version to start from
  # @return [Array<InventoryEvents::BaseEvent>] array of domain events
  def get_events_since_version(aggregate_id, since_version)
    records = InventoryEventRecord
      .where(aggregate_id: aggregate_id)
      .where('version > ?', since_version)
      .order(:version)

    records.map(&:to_domain_event)
  end

  # Get current version for an aggregate
  # @param aggregate_id [String] aggregate identifier
  # @return [Integer] current version number
  def current_version(aggregate_id)
    record = InventoryEventRecord.where(aggregate_id: aggregate_id).order(version: :desc).first
    record&.version || 0
  end

  # Check if aggregate exists
  # @param aggregate_id [String] aggregate identifier
  # @return [Boolean] true if aggregate has events
  def aggregate_exists?(aggregate_id)
    InventoryEventRecord.where(aggregate_id: aggregate_id).exists?
  end

  # Get all aggregate IDs
  # @return [Array<String>] array of aggregate IDs
  def get_all_aggregate_ids
    InventoryEventRecord.distinct.pluck(:aggregate_id)
  end

  # Archive old events for an aggregate
  # @param aggregate_id [String] aggregate identifier
  # @param older_than [Time] archive events older than this time
  # @return [Integer] number of events archived
  def archive_old_events(aggregate_id, older_than = 1.year.ago)
    count = InventoryEventRecord
      .where(aggregate_id: aggregate_id)
      .where('timestamp < ?', older_than)
      .update_all(archived: true)

    Rails.logger.info("Archived #{count} old events for aggregate #{aggregate_id}")
    count
  end

  private

  # Update aggregate projection after event append
  # @param aggregate_id [String] aggregate identifier
  # @param version [Integer] new version
  # @param event [InventoryEvents::BaseEvent] triggering event
  def update_aggregate_projection(aggregate_id, version, event)
    # This would typically update a projections table or trigger projection updates
    # For now, we'll use a simple approach with the existing model

    case event
    when InventoryEvents::InventoryCreated
      ensure_projection_exists(aggregate_id, event)
    when InventoryEvents::QuantityChanged, InventoryEvents::InventoryReserved,
         InventoryEvents::InventoryReleased, InventoryEvents::InventoryAllocated,
         InventoryEvents::InventorySynchronized, InventoryEvents::InventoryReplenished
      update_projection_state(aggregate_id, version, event)
    end
  end

  # Ensure aggregate projection exists
  # @param aggregate_id [String] aggregate identifier
  # @param event [InventoryEvents::InventoryCreated] creation event
  def ensure_projection_exists(aggregate_id, event)
    # This would create or update the read model projection
    # For now, we'll rely on the existing ChannelInventory model
  end

  # Update projection state after state-changing event
  # @param aggregate_id [String] aggregate identifier
  # @param version [Integer] new version
  # @param event [InventoryEvents::BaseEvent] triggering event
  def update_projection_state(aggregate_id, version, event)
    # This would update read model projections
    # For now, we'll trigger a background job for projection updates
    InventoryProjectionUpdateJob.perform_async(aggregate_id, version, event.to_h)
  end
end

# ActiveRecord model for storing events
class InventoryEventRecord < ApplicationRecord
  self.table_name = 'inventory_event_records'

  # Serialize event data as JSON
  serialize :event_data, JSON

  # Validations
  validates :aggregate_id, presence: true
  validates :event_type, presence: true
  validates :event_data, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :timestamp, presence: true

  # Indexes for performance
  # Note: These would be added via migration in a real implementation

  # Scope for unarchived events
  scope :active, -> { where(archived: false) }

  # Scope for events in version order
  scope :in_order, -> { order(:aggregate_id, :version) }
end

# Background job for updating projections
class InventoryProjectionUpdateJob
  include Sidekiq::Job

  # Perform projection update
  # @param aggregate_id [String] aggregate identifier
  # @param version [Integer] version to update to
  # @param event_data [Hash] event data for update
  def perform(aggregate_id, version, event_data)
    # This would update read model projections based on the event
    # For now, we'll update the existing ChannelInventory model

    event = reconstruct_event_from_data(event_data)
    return unless event

    update_channel_inventory_projection(aggregate_id, version, event)
  rescue => e
    Rails.logger.error("Failed to update projection for aggregate #{aggregate_id}: #{e.message}")
    raise e
  end

  private

  # Reconstruct event from serialized data
  # @param event_data [Hash] serialized event data
  # @return [InventoryEvents::BaseEvent, nil] reconstructed event
  def reconstruct_event_from_data(event_data)
    event_type = event_data['event_type']
    return nil unless event_type

    # This is a simplified reconstruction - in practice you'd use proper deserialization
    aggregate_id = event_data['aggregate_id']
    metadata = event_data['metadata'] || {}

    case event_type
    when 'InventoryEvents::InventoryCreated'
      InventoryEvents::InventoryCreated.new(
        aggregate_id,
        event_data['product_id'],
        event_data['sales_channel_id'],
        event_data['initial_quantity']
      )
    when 'InventoryEvents::QuantityChanged'
      InventoryEvents::QuantityChanged.new(
        aggregate_id,
        event_data['old_quantity'],
        event_data['new_quantity'],
        reason: event_data['reason']&.to_sym,
        triggered_by: event_data['triggered_by']
      )
    when 'InventoryEvents::InventoryReserved'
      InventoryEvents::InventoryReserved.new(
        aggregate_id,
        event_data['reserved_amount'],
        order_id: event_data['order_id'],
        expires_at: Time.parse(event_data['expires_at'])
      )
    when 'InventoryEvents::InventoryReleased'
      InventoryEvents::InventoryReleased.new(
        aggregate_id,
        event_data['released_amount'],
        order_id: event_data['order_id'],
        reason: event_data['reason']&.to_sym
      )
    when 'InventoryEvents::InventoryAllocated'
      InventoryEvents::InventoryAllocated.new(
        aggregate_id,
        event_data['allocated_amount'],
        event_data['order_id'],
        shipment_id: event_data['shipment_id']
      )
    when 'InventoryEvents::InventorySynchronized'
      InventoryEvents::InventorySynchronized.new(
        aggregate_id,
        event_data['source_quantity'],
        event_data['previous_quantity'],
        sync_source: event_data['sync_source']
      )
    else
      nil
    end
  end

  # Update channel inventory projection based on event
  # @param aggregate_id [String] aggregate identifier
  # @param version [Integer] new version
  # @param event [InventoryEvents::BaseEvent] triggering event
  def update_channel_inventory_projection(aggregate_id, version, event)
    # Extract product_id and sales_channel_id from aggregate_id
    # Format: "inventory_{product_id}_{sales_channel_id}_{timestamp}"
    parts = aggregate_id.split('_')
    return unless parts.length >= 3

    product_id = parts[1].to_i
    sales_channel_id = parts[2].to_i

    # Find or create the projection record
    projection = ChannelInventoryProjection.find_or_create_by(
      product_id: product_id,
      sales_channel_id: sales_channel_id
    )

    # Update projection based on event type
    update_projection_from_event(projection, event)
    projection.last_event_version = version
    projection.last_updated_at = Time.current
    projection.save!
  end

  # Update projection record from domain event
  # @param projection [ChannelInventoryProjection] projection to update
  # @param event [InventoryEvents::BaseEvent] event to apply
  def update_projection_from_event(projection, event)
    case event
    when InventoryEvents::InventoryCreated
      projection.quantity = event.initial_quantity
      projection.reserved_quantity = 0
      projection.status = :in_stock
    when InventoryEvents::QuantityChanged
      projection.quantity = event.new_quantity
    when InventoryEvents::InventoryReserved
      projection.reserved_quantity += event.reserved_amount
    when InventoryEvents::InventoryReleased
      projection.reserved_quantity -= event.released_amount
      projection.reserved_quantity = [projection.reserved_quantity, 0].max
    when InventoryEvents::InventoryAllocated
      projection.quantity -= event.allocated_amount
      projection.reserved_quantity -= [event.allocated_amount, projection.reserved_quantity].min
    when InventoryEvents::InventorySynchronized
      projection.quantity = event.source_quantity
    end

    # Update calculated status
    projection.status = calculate_projection_status(projection)
  end

  # Calculate status for projection record
  # @param projection [ChannelInventoryProjection] projection to assess
  # @return [Symbol] calculated status
  def calculate_projection_status(projection)
    available = projection.quantity - projection.reserved_quantity

    case available
    when 0 then :out_of_stock
    when 1..10 then :low_stock
    else :in_stock
    end
  end
end

# Read model projection for ChannelInventory
class ChannelInventoryProjection < ApplicationRecord
  self.table_name = 'channel_inventory_projections'

  # Associations
  belongs_to :product
  belongs_to :sales_channel

  # Validations
  validates :product_id, presence: true
  validates :sales_channel_id, presence: true
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true

  # Ensure reserved quantity doesn't exceed total
  validate :reserved_quantity_within_bounds

  # Scopes
  scope :in_stock, -> { where('quantity > reserved_quantity') }
  scope :out_of_stock, -> { where('quantity <= reserved_quantity') }
  scope :low_stock, -> { where('quantity > reserved_quantity AND quantity <= reserved_quantity + 10') }

  # Get available quantity
  # @return [Integer] available quantity
  def available_quantity
    [quantity - reserved_quantity, 0].max
  end

  # Check if in stock
  # @return [Boolean] true if available
  def in_stock?
    available_quantity > 0
  end

  private

  # Validation: reserved quantity cannot exceed total
  def reserved_quantity_within_bounds
    if reserved_quantity > quantity
      errors.add(:reserved_quantity, 'cannot exceed total quantity')
    end
  end
end