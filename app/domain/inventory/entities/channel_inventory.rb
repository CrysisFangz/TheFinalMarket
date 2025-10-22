# frozen_string_literal: true

# Aggregate root for Channel Inventory domain entity
# Manages inventory state, business rules, and domain events
class ChannelInventory
  attr_reader :id, :product_id, :sales_channel_id, :quantity, :status,
              :created_at, :updated_at, :version, :uncommitted_events

  # Initialize new channel inventory aggregate
  # @param id [String] unique identifier for this inventory
  # @param product_id [Integer] ID of the associated product
  # @param sales_channel_id [Integer] ID of the sales channel
  # @param initial_quantity [Integer] initial inventory quantity
  def initialize(id, product_id, sales_channel_id, initial_quantity)
    @id = id
    @product_id = product_id
    @sales_channel_id = sales_channel_id
    @created_at = Time.current
    @updated_at = @created_at
    @version = 1
    @uncommitted_events = []

    # Initialize with quantity value object
    initial_quantity_obj = Quantity.new(initial_quantity)
    @quantity = initial_quantity_obj

    # Calculate initial status
    @status = InventoryStatus.new(@quantity)

    # Apply domain events for creation
    apply_inventory_created_event
    freeze # Make aggregate root immutable
  end

  # Load aggregate from event stream
  # @param id [String] aggregate identifier
  # @param events [Array<InventoryEvents::BaseEvent>] historical events
  # @return [ChannelInventory] reconstructed aggregate
  def self.from_events(id, events)
    return nil if events.empty?

    # Create instance without calling constructor
    instance = allocate

    # Set initial state
    instance.instance_variable_set(:@id, id)
    instance.instance_variable_set(:@created_at, events.first.timestamp)
    instance.instance_variable_set(:@updated_at, events.first.timestamp)
    instance.instance_variable_set(:@version, 0)
    instance.instance_variable_set(:@uncommitted_events, [])

    # Apply all events to reconstruct current state
    events.each do |event|
      instance.apply_event(event)
    end

    instance.freeze
    instance
  end

  # Reserve inventory for an order
  # @param amount [Integer] amount to reserve
  # @param order_id [String] ID of the order making the reservation
  # @param expires_at [Time] when reservation expires
  # @return [Boolean] true if reservation was successful
  def reserve_inventory(amount, order_id: nil, expires_at: nil)
    return false unless @quantity.available?(amount)

    # Create new quantity with reservation
    new_quantity = @quantity.reserve(amount)

    # Apply domain event
    apply_event(InventoryEvents::InventoryReserved.new(
      @id,
      amount,
      order_id: order_id,
      expires_at: expires_at || 24.hours.from_now
    ))

    # Update state (this would normally be done by event sourcing)
    @quantity = new_quantity
    @status = InventoryStatus.new(@quantity)
    @updated_at = Time.current

    true
  end

  # Release previously reserved inventory
  # @param amount [Integer] amount to release
  # @param order_id [String] ID of the order releasing inventory
  # @return [Boolean] true if release was successful
  def release_inventory(amount, order_id: nil)
    # Calculate actual amount to release (cannot exceed reserved quantity)
    actual_release = [amount, @quantity.reserved].min

    return false if actual_release.zero?

    # Create new quantity with reduced reservation
    new_quantity = @quantity.release(actual_release)

    # Apply domain event
    apply_event(InventoryEvents::InventoryReleased.new(
      @id,
      actual_release,
      order_id: order_id,
      reason: :manual
    ))

    # Update state
    @quantity = new_quantity
    @status = InventoryStatus.new(@quantity)
    @updated_at = Time.current

    true
  end

  # Allocate inventory to a completed order
  # @param amount [Integer] amount to allocate
  # @param order_id [String] ID of the order allocating inventory
  # @param shipment_id [String] ID of the shipment (if applicable)
  # @return [Boolean] true if allocation was successful
  def allocate_inventory(amount, order_id, shipment_id: nil)
    return false if @quantity.value < amount

    # Create new quantity after allocation
    new_quantity = @quantity.allocate(amount)

    # Apply domain event
    apply_event(InventoryEvents::InventoryAllocated.new(
      @id,
      amount,
      order_id,
      shipment_id: shipment_id
    ))

    # Update state
    @quantity = new_quantity
    @status = InventoryStatus.new(@quantity)
    @updated_at = Time.current

    true
  end

  # Add inventory (replenishment)
  # @param amount [Integer] amount to add
  # @param source [String] source of the replenishment
  # @return [Boolean] true if replenishment was successful
  def replenish_inventory(amount, source: 'manual')
    return false if amount <= 0

    # Create new quantity with added inventory
    new_quantity = @quantity.add(amount)

    # Apply domain events
    apply_event(InventoryEvents::QuantityChanged.new(
      @id,
      @quantity.value,
      new_quantity.value,
      reason: :replenishment,
      triggered_by: source
    ))

    apply_event(InventoryEvents::InventoryReplenished.new(
      @id,
      amount,
      new_quantity.value,
      replenishment_source: source
    ))

    # Update state
    @quantity = new_quantity
    @status = InventoryStatus.new(@quantity)
    @updated_at = Time.current

    true
  end

  # Synchronize inventory from external source
  # @param source_quantity [Integer] quantity from source system
  # @param source [String] source system identifier
  # @return [Boolean] true if sync was successful
  def sync_inventory(source_quantity, source: 'external')
    # Validate source quantity
    return false if source_quantity.negative?

    # Calculate difference
    quantity_diff = source_quantity - @quantity.value

    # Apply appropriate events based on difference
    if quantity_diff > 0
      # Inventory increased
      apply_event(InventoryEvents::QuantityChanged.new(
        @id,
        @quantity.value,
        source_quantity,
        reason: :sync_increase,
        triggered_by: source
      ))
    elsif quantity_diff < 0
      # Inventory decreased
      apply_event(InventoryEvents::QuantityChanged.new(
        @id,
        @quantity.value,
        source_quantity,
        reason: :sync_decrease,
        triggered_by: source
      ))
    else
      # No change - still record sync event for audit
      apply_event(InventoryEvents::InventorySynchronized.new(
        @id,
        source_quantity,
        @quantity.value,
        sync_source: source
      ))

      return true
    end

    # Record synchronization event
    apply_event(InventoryEvents::InventorySynchronized.new(
      @id,
      source_quantity,
      @quantity.value,
      sync_source: source
    ))

    # Update state
    new_quantity = Quantity.new(source_quantity, reserved: @quantity.reserved)
    @quantity = new_quantity
    @status = InventoryStatus.new(@quantity)
    @updated_at = Time.current

    true
  end

  # Check if inventory can fulfill a request
  # @param amount [Integer] amount requested
  # @return [Hash] fulfillment assessment
  def can_fulfill?(amount)
    return {
      can_fulfill: false,
      reason: :negative_amount,
      available: @quantity.available
    } if amount <= 0

    return {
      can_fulfill: false,
      reason: :insufficient_quantity,
      available: @quantity.available,
      requested: amount
    } if amount > @quantity.value

    return {
      can_fulfill: false,
      reason: :insufficient_available,
      available: @quantity.available,
      requested: amount
    } if amount > @quantity.available

    {
      can_fulfill: true,
      available: @quantity.available,
      requested: amount,
      utilization_impact: calculate_utilization_impact(amount)
    }
  end

  # Get current inventory summary
  # @return [Hash] summary of current state
  def summary
    {
      id: @id,
      product_id: @product_id,
      sales_channel_id: @sales_channel_id,
      quantity: @quantity.to_h,
      status: @status.to_h,
      created_at: @created_at,
      updated_at: @updated_at,
      version: @version,
      pending_events: @uncommitted_events.length
    }
  end

  # Check if inventory needs attention based on current status
  # @return [Hash] attention requirements
  def attention_needed?
    attention = {
      needs_attention: false,
      reasons: [],
      priority: :low,
      recommended_actions: []
    }

    # Check for critical status conditions
    if @status.out_of_stock?
      attention[:needs_attention] = true
      attention[:reasons] << :out_of_stock
      attention[:priority] = :critical
      attention[:recommended_actions] << :restock_immediately
    elsif @status.low_stock?
      attention[:needs_attention] = true
      attention[:reasons] << :low_stock
      attention[:priority] = :high
      attention[:recommended_actions] << :schedule_restock
    elsif @status.overstocked?
      attention[:needs_attention] = true
      attention[:reasons] << :overstocked
      attention[:priority] = :medium
      attention[:recommended_actions] << :consider_promotions
    end

    # Check for high reservation rate
    if @quantity.utilization_rate > 0.8
      attention[:needs_attention] = true
      attention[:reasons] << :high_reservation_rate
      attention[:priority] = attention[:needs_attention] ? [:high, attention[:priority]].min : :medium
      attention[:recommended_actions] << :monitor_reservations
    end

    attention
  end

  # Apply domain event to change aggregate state
  # @param event [InventoryEvents::BaseEvent] event to apply
  def apply_event(event)
    case event
    when InventoryEvents::InventoryCreated
      apply_creation_event(event)
    when InventoryEvents::QuantityChanged
      apply_quantity_change_event(event)
    when InventoryEvents::InventoryReserved
      apply_reservation_event(event)
    when InventoryEvents::InventoryReleased
      apply_release_event(event)
    when InventoryEvents::InventoryAllocated
      apply_allocation_event(event)
    when InventoryEvents::InventorySynchronized
      apply_sync_event(event)
    when InventoryEvents::LowStockAlertTriggered
      apply_low_stock_alert_event(event)
    when InventoryEvents::StockoutOccurred
      apply_stockout_event(event)
    when InventoryEvents::InventoryReplenished
      apply_replenishment_event(event)
    when InventoryEvents::ReservationExpired
      apply_reservation_expiry_event(event)
    when InventoryEvents::ThresholdAdjusted
      apply_threshold_adjustment_event(event)
    when InventoryEvents::InventoryAudited
      apply_audit_event(event)
    end

    @version += 1
    @updated_at = event.timestamp
  end

  # Add event to uncommitted events list
  # @param event [InventoryEvents::BaseEvent] event to add
  def add_uncommitted_event(event)
    @uncommitted_events << event
  end

  # Mark all events as committed
  def mark_events_committed
    @uncommitted_events.clear
  end

  # Equality comparison based on business identity
  # @param other [ChannelInventory] inventory to compare with
  # @return [Boolean] true if inventories represent the same business entity
  def ==(other)
    other.is_a?(ChannelInventory) &&
    @id == other.id &&
    @product_id == other.product_id &&
    @sales_channel_id == other.sales_channel_id
  end

  alias eql? ==

  # Hash for use in hash-based collections
  # @return [Integer] hash code based on business identity
  def hash
    [@id, @product_id, @sales_channel_id].hash
  end

  private

  # Apply inventory creation event
  # @param event [InventoryEvents::InventoryCreated] creation event
  def apply_creation_event(event)
    # State already initialized in constructor
  end

  # Apply quantity change event
  # @param event [InventoryEvents::QuantityChanged] quantity change event
  def apply_quantity_change_event(event)
    new_quantity = Quantity.new(event.new_quantity, reserved: @quantity.reserved)
    @quantity = new_quantity
  end

  # Apply reservation event
  # @param event [InventoryEvents::InventoryReserved] reservation event
  def apply_reservation_event(event)
    new_quantity = @quantity.reserve(event.reserved_amount)
    @quantity = new_quantity
  end

  # Apply release event
  # @param event [InventoryEvents::InventoryReleased] release event
  def apply_release_event(event)
    new_quantity = @quantity.release(event.released_amount)
    @quantity = new_quantity
  end

  # Apply allocation event
  # @param event [InventoryEvents::InventoryAllocated] allocation event
  def apply_allocation_event(event)
    new_quantity = @quantity.allocate(event.allocated_amount)
    @quantity = new_quantity
  end

  # Apply synchronization event
  # @param event [InventoryEvents::InventorySynchronized] sync event
  def apply_sync_event(event)
    new_quantity = Quantity.new(event.source_quantity, reserved: @quantity.reserved)
    @quantity = new_quantity
  end

  # Apply low stock alert event
  # @param event [InventoryEvents::LowStockAlertTriggered] alert event
  def apply_low_stock_alert_event(event)
    # Status will be recalculated when needed
  end

  # Apply stockout event
  # @param event [InventoryEvents::StockoutOccurred] stockout event
  def apply_stockout_event(event)
    # Status will be recalculated when needed
  end

  # Apply replenishment event
  # @param event [InventoryEvents::InventoryReplenished] replenishment event
  def apply_replenishment_event(event)
    new_quantity = Quantity.new(event.new_total_quantity, reserved: @quantity.reserved)
    @quantity = new_quantity
  end

  # Apply reservation expiry event
  # @param event [InventoryEvents::ReservationExpired] expiry event
  def apply_reservation_expiry_event(event)
    new_quantity = @quantity.release(event.expired_amount)
    @quantity = new_quantity
  end

  # Apply threshold adjustment event
  # @param event [InventoryEvents::ThresholdAdjusted] threshold event
  def apply_threshold_adjustment_event(event)
    # Threshold adjustments don't change current state, only future behavior
  end

  # Apply audit event
  # @param event [InventoryEvents::InventoryAudited] audit event
  def apply_audit_event(event)
    # Audit results may trigger corrections if discrepancies are found
    if event.discrepancy != 0
      new_quantity = Quantity.new(event.audited_quantity, reserved: @quantity.reserved)
      @quantity = new_quantity
    end
  end

  # Apply inventory created event and add to uncommitted events
  def apply_inventory_created_event
    event = InventoryEvents::InventoryCreated.new(
      @id,
      @product_id,
      @sales_channel_id,
      @quantity.value
    )
    add_uncommitted_event(event)
  end

  # Calculate impact of allocation on utilization
  # @param amount [Integer] amount being allocated
  # @return [Hash] utilization impact analysis
  def calculate_utilization_impact(amount)
    current_utilization = @quantity.utilization_rate
    new_utilization = (@quantity.reserved + amount).to_f / @quantity.value

    {
      current_utilization: current_utilization,
      new_utilization: new_utilization,
      utilization_change: new_utilization - current_utilization,
      utilization_category: categorize_utilization(new_utilization)
    }
  end

  # Categorize utilization rate for business intelligence
  # @param utilization_rate [Float] utilization rate (0.0 to 1.0)
  # @return [Symbol] utilization category
  def categorize_utilization(utilization_rate)
    case utilization_rate
    when 0.0..0.3 then :low
    when 0.3..0.7 then :moderate
    when 0.7..0.9 then :high
    else :critical
    end
  end
end