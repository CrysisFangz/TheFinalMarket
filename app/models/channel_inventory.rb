# frozen_string_literal: true

class ChannelInventory < ApplicationRecord
  # Associations
  belongs_to :sales_channel, inverse_of: :channel_inventories
  belongs_to :product, inverse_of: :channel_inventories

  has_many :inventory_events, dependent: :destroy
  has_many :inventory_snapshots, dependent: :destroy
  has_many :inventory_audits, dependent: :destroy

  # Validations
  validates :sales_channel, presence: true
  validates :product, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :reserved_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :allocated_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :product_id, uniqueness: { scope: :sales_channel_id }

  # Use Query Objects for complex queries
  def self.in_stock
    Queries::InventoryQueries.in_stock
  end

  def self.out_of_stock
    Queries::InventoryQueries.out_of_stock
  end

  def self.low_stock(threshold = 10)
    Queries::InventoryQueries.low_stock(threshold)
  end

  def self.critical_stock
    Queries::InventoryQueries.critical_stock
  end

  def self.overstocked(threshold = 1000)
    Queries::InventoryQueries.overstocked(threshold)
  end

  def self.recently_synced(timeframe = 1.hour)
    Queries::InventoryQueries.recently_synced(timeframe)
  end

  def self.needs_attention
    Queries::InventoryQueries.needs_attention
  end

  # Delegate operations to services
  def reserve!(amount, order_id: nil, expires_at: nil, correlation_id: nil)
    service = InventoryReservationService.new(self)
    service.reserve(amount, order_id: order_id, expires_at: expires_at, correlation_id: correlation_id)
  end

  def release!(amount, order_id: nil, reason: :manual, correlation_id: nil)
    service = InventoryReleaseService.new(self)
    service.release(amount, order_id: order_id, reason: reason, correlation_id: correlation_id)
  end

  def allocate!(amount, order_id:, shipment_id: nil, correlation_id: nil)
    service = InventoryAllocationService.new(self)
    service.allocate(amount, order_id: order_id, shipment_id: shipment_id, correlation_id: correlation_id)
  end

  def add!(amount, source: 'manual', correlation_id: nil, metadata: {})
    service = InventoryReplenishmentService.new(self)
    service.add(amount, source: source, correlation_id: correlation_id, metadata: metadata)
  end

  # Domain entity integration
  def domain_entity
    @domain_entity ||= load_or_create_domain_entity
  end

  def uncommitted_events
    domain_entity&.uncommitted_events || []
  end

  def apply_domain_events(events)
    return if events.empty?

    sorted_events = events.sort_by(&:timestamp)
    sorted_events.each { |event| persist_domain_event(event) }
    update_aggregate_state_from_events(sorted_events)
    domain_entity.mark_events_committed if domain_entity.respond_to?(:mark_events_committed)

    # Invalidate caches after state change
    Cache::InventoryCacheManager.invalidate_related_caches(id, product_id, sales_channel_id, version)
  end

  def load_or_create_domain_entity
    events = inventory_events.order(:sequence_number).map(&:to_domain_event)
    if events.any?
      Domain::Entities::ChannelInventoryEntity.from_events(composite_id, events)
    else
      Domain::Entities::ChannelInventoryEntity.new(composite_id, product_id, sales_channel_id, quantity)
    end
  end

  def composite_id
    @composite_id ||= "ChannelInventory:#{id}:#{product_id}:#{sales_channel_id}"
  end

  def available_quantity
    domain_entity.summary[:quantity][:available]
  end

  def stock_status
    cache_key = Cache::InventoryCacheManager.stock_status_key(id, version)
    cached_status = Cache::InventoryCacheManager.get_stock_status(id, version)
    return cached_status if cached_status

    status = domain_entity.summary[:status]
    Cache::InventoryCacheManager.set_stock_status(id, version, status)
    status
  end

  def alerts
    domain_entity.attention_needed?
  end

  def days_until_stockout(allocation_rate: nil)
    current_quantity = domain_entity.summary[:quantity][:available]
    return 0 if current_quantity <= 0

    rate = allocation_rate || calculate_historical_allocation_rate
    return nil if rate <= 0

    (current_quantity / rate).to_i
  end

  # Simplified methods
  def broadcast_inventory_update
    InventoryChannel.broadcast_to(
      "channel:#{sales_channel_id}",
      {
        type: 'inventory_updated',
        inventory_id: id,
        product_id: product_id,
        quantity: quantity,
        reserved_quantity: reserved_quantity,
        available_quantity: available_quantity,
        timestamp: Time.current
      }
    )
  end

  def record_successful_operation(operation_type, amount, operation_id)
    inventory_operation_logs.create!(
      operation_type: operation_type,
      amount: amount,
      success: true,
      operation_id: operation_id,
      duration: 0.001, # Placeholder
      metadata: { correlation_id: operation_id }
    )
  end

  def record_failed_operation(operation_type, amount, reason, message = nil)
    inventory_operation_logs.create!(
      operation_type: operation_type,
      amount: amount,
      success: false,
      failure_reason: reason,
      failure_message: message,
      metadata: {
        current_quantity: quantity,
        available_quantity: available_quantity,
        reserved_quantity: reserved_quantity
      }
    )
  end

  def record_circuit_breaker_failure(operation_type, amount, error)
    record_failed_operation(operation_type, amount, :circuit_breaker_open, error.message)
  end

  private

  def persist_domain_event(event)
    inventory_events.create!(
      event_type: event.class.name,
      event_data: event.to_h,
      sequence_number: next_sequence_number,
      correlation_id: event.correlation_id,
      causation_id: event.causation_id,
      timestamp: event.timestamp
    )
  end

  def update_aggregate_state_from_events(events)
    latest_event = events.last
    update!(
      quantity: latest_event.quantity_after || quantity,
      reserved_quantity: latest_event.reserved_after || reserved_quantity,
      allocated_quantity: latest_event.allocated_after || allocated_quantity,
      version: latest_event.aggregate_version || version,
      last_event_at: latest_event.timestamp
    )
  end

  def next_sequence_number
    (inventory_events.maximum(:sequence_number) || 0) + 1
  end

  def calculate_historical_allocation_rate
    recent_allocations = inventory_events
      .where(event_type: 'Domain::Events::InventoryAllocated')
      .where('created_at > ?', 30.days.ago)
      .sum('CAST(event_data->>\'amount\' AS INTEGER)')
    days = 30
    recent_allocations.to_f / days
  end

  def record_supply_chain_event(event_type, amount, source, metadata)
    inventory_supply_chain_events.create!(
      event_type: event_type,
      amount: amount,
      source: source,
      metadata: metadata,
      recorded_at: Time.current
    )
  end
end