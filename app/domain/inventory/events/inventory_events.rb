# frozen_string_literal: true

# Domain events for inventory management
# All events are immutable and represent state changes in the inventory domain
module InventoryEvents
  # Base class for all inventory domain events
  class BaseEvent
    attr_reader :aggregate_id, :event_id, :timestamp, :version, :metadata

    # Initialize base event properties
    # @param aggregate_id [String] ID of the aggregate this event belongs to
    # @param metadata [Hash] additional event metadata
    def initialize(aggregate_id, metadata: {})
      @aggregate_id = aggregate_id
      @event_id = SecureRandom.uuid
      @timestamp = Time.current
      @version = 1
      @metadata = metadata.freeze
      freeze # Make immutable
    end

    # Convert event to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      {
        event_type: event_type,
        aggregate_id: @aggregate_id,
        event_id: @event_id,
        timestamp: @timestamp,
        version: @version,
        metadata: @metadata
      }
    end

    # Get event type for polymorphic identification
    # @return [String] event type identifier
    def event_type
      self.class.name.demodulize
    end

    private

    # Ensure subclasses implement their specific serialization
    def freeze
      super
    end
  end

  # Event fired when inventory is created or initialized
  class InventoryCreated < BaseEvent
    attr_reader :product_id, :sales_channel_id, :initial_quantity, :created_by

    # Initialize inventory creation event
    # @param aggregate_id [String] inventory aggregate ID
    # @param product_id [Integer] ID of the product
    # @param sales_channel_id [Integer] ID of the sales channel
    # @param initial_quantity [Integer] initial stock quantity
    # @param created_by [String] user/system that created the inventory
    def initialize(aggregate_id, product_id, sales_channel_id, initial_quantity, created_by: nil)
      super(aggregate_id, metadata: { created_by: created_by })
      @product_id = product_id
      @sales_channel_id = sales_channel_id
      @initial_quantity = initial_quantity
      @created_by = created_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        product_id: @product_id,
        sales_channel_id: @sales_channel_id,
        initial_quantity: @initial_quantity,
        created_by: @created_by
      )
    end
  end

  # Event fired when inventory quantity changes
  class QuantityChanged < BaseEvent
    attr_reader :old_quantity, :new_quantity, :change_amount, :reason, :triggered_by

    # Initialize quantity change event
    # @param aggregate_id [String] inventory aggregate ID
    # @param old_quantity [Integer] previous quantity
    # @param new_quantity [Integer] new quantity
    # @param reason [Symbol] reason for the change
    # @param triggered_by [String] what triggered the change
    def initialize(aggregate_id, old_quantity, new_quantity, reason: :manual, triggered_by: nil)
      super(aggregate_id, metadata: { triggered_by: triggered_by })
      @old_quantity = old_quantity
      @new_quantity = new_quantity
      @change_amount = new_quantity - old_quantity
      @reason = reason
      @triggered_by = triggered_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        old_quantity: @old_quantity,
        new_quantity: @new_quantity,
        change_amount: @change_amount,
        reason: @reason,
        triggered_by: @triggered_by
      )
    end
  end

  # Event fired when inventory is reserved for an order
  class InventoryReserved < BaseEvent
    attr_reader :reserved_amount, :order_id, :expires_at, :reserved_by

    # Initialize inventory reservation event
    # @param aggregate_id [String] inventory aggregate ID
    # @param reserved_amount [Integer] amount being reserved
    # @param order_id [String] ID of the order reserving inventory
    # @param expires_at [Time] when the reservation expires
    # @param reserved_by [String] user/system making the reservation
    def initialize(aggregate_id, reserved_amount, order_id: nil, expires_at: nil, reserved_by: nil)
      super(aggregate_id, metadata: { reserved_by: reserved_by })
      @reserved_amount = reserved_amount
      @order_id = order_id
      @expires_at = expires_at || 24.hours.from_now # Default 24 hour expiry
      @reserved_by = reserved_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        reserved_amount: @reserved_amount,
        order_id: @order_id,
        expires_at: @expires_at,
        reserved_by: @reserved_by
      )
    end
  end

  # Event fired when reserved inventory is released
  class InventoryReleased < BaseEvent
    attr_reader :released_amount, :order_id, :reason, :released_by

    # Initialize inventory release event
    # @param aggregate_id [String] inventory aggregate ID
    # @param released_amount [Integer] amount being released
    # @param order_id [String] ID of the order that had reserved inventory
    # @param reason [Symbol] reason for the release
    # @param released_by [String] user/system releasing the inventory
    def initialize(aggregate_id, released_amount, order_id: nil, reason: :manual, released_by: nil)
      super(aggregate_id, metadata: { released_by: released_by })
      @released_amount = released_amount
      @order_id = order_id
      @reason = reason
      @released_by = released_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        released_amount: @released_amount,
        order_id: @order_id,
        reason: @reason,
        released_by: @released_by
      )
    end
  end

  # Event fired when inventory is allocated to a completed order
  class InventoryAllocated < BaseEvent
    attr_reader :allocated_amount, :order_id, :shipment_id, :allocated_by

    # Initialize inventory allocation event
    # @param aggregate_id [String] inventory aggregate ID
    # @param allocated_amount [Integer] amount being allocated
    # @param order_id [String] ID of the order inventory is allocated to
    # @param shipment_id [String] ID of the shipment (if applicable)
    # @param allocated_by [String] user/system allocating the inventory
    def initialize(aggregate_id, allocated_amount, order_id, shipment_id: nil, allocated_by: nil)
      super(aggregate_id, metadata: { allocated_by: allocated_by })
      @allocated_amount = allocated_amount
      @order_id = order_id
      @shipment_id = shipment_id
      @allocated_by = allocated_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        allocated_amount: @allocated_amount,
        order_id: @order_id,
        shipment_id: @shipment_id,
        allocated_by: @allocated_by
      )
    end
  end

  # Event fired when inventory is synchronized from external source
  class InventorySynchronized < BaseEvent
    attr_reader :source_quantity, :previous_quantity, :sync_source, :synchronized_by

    # Initialize inventory synchronization event
    # @param aggregate_id [String] inventory aggregate ID
    # @param source_quantity [Integer] quantity from the source system
    # @param previous_quantity [Integer] quantity before synchronization
    # @param sync_source [String] source of the synchronization
    # @param synchronized_by [String] user/system performing sync
    def initialize(aggregate_id, source_quantity, previous_quantity, sync_source: 'external', synchronized_by: nil)
      super(aggregate_id, metadata: { synchronized_by: synchronized_by })
      @source_quantity = source_quantity
      @previous_quantity = previous_quantity
      @sync_source = sync_source
      @synchronized_by = synchronized_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        source_quantity: @source_quantity,
        previous_quantity: @previous_quantity,
        sync_source: @sync_source,
        synchronized_by: @synchronized_by
      )
    end
  end

  # Event fired when low stock alert threshold is triggered
  class LowStockAlertTriggered < BaseEvent
    attr_reader :current_quantity, :threshold, :alert_severity, :triggered_by

    # Initialize low stock alert event
    # @param aggregate_id [String] inventory aggregate ID
    # @param current_quantity [Integer] current inventory quantity
    # @param threshold [Integer] threshold that was crossed
    # @param alert_severity [Symbol] severity of the alert
    # @param triggered_by [String] what triggered the alert
    def initialize(aggregate_id, current_quantity, threshold, alert_severity: :warning, triggered_by: 'system')
      super(aggregate_id, metadata: { triggered_by: triggered_by })
      @current_quantity = current_quantity
      @threshold = threshold
      @alert_severity = alert_severity
      @triggered_by = triggered_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        current_quantity: @current_quantity,
        threshold: @threshold,
        alert_severity: @alert_severity,
        triggered_by: @triggered_by
      )
    end
  end

  # Event fired when stockout occurs
  class StockoutOccurred < BaseEvent
    attr_reader :previous_quantity, :out_of_stock_at, :estimated_recovery_time, :triggered_by

    # Initialize stockout event
    # @param aggregate_id [String] inventory aggregate ID
    # @param previous_quantity [Integer] quantity before stockout
    # @param out_of_stock_at [Time] when stockout occurred
    # @param estimated_recovery_time [Time] estimated time to recover
    # @param triggered_by [String] what triggered the stockout
    def initialize(aggregate_id, previous_quantity, out_of_stock_at: nil, estimated_recovery_time: nil, triggered_by: 'allocation')
      super(aggregate_id, metadata: { triggered_by: triggered_by })
      @previous_quantity = previous_quantity
      @out_of_stock_at = out_of_stock_at || Time.current
      @estimated_recovery_time = estimated_recovery_time
      @triggered_by = triggered_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        previous_quantity: @previous_quantity,
        out_of_stock_at: @out_of_stock_at,
        estimated_recovery_time: @estimated_recovery_time,
        triggered_by: @triggered_by
      )
    end
  end

  # Event fired when inventory is replenished
  class InventoryReplenished < BaseEvent
    attr_reader :replenished_amount, :new_total_quantity, :replenishment_source, :replenished_by

    # Initialize inventory replenishment event
    # @param aggregate_id [String] inventory aggregate ID
    # @param replenished_amount [Integer] amount that was replenished
    # @param new_total_quantity [Integer] new total quantity after replenishment
    # @param replenishment_source [String] source of the replenishment
    # @param replenished_by [String] user/system that replenished
    def initialize(aggregate_id, replenished_amount, new_total_quantity, replenishment_source: 'manual', replenished_by: nil)
      super(aggregate_id, metadata: { replenished_by: replenished_by })
      @replenished_amount = replenished_amount
      @new_total_quantity = new_total_quantity
      @replenishment_source = replenishment_source
      @replenished_by = replenished_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        replenished_amount: @replenished_amount,
        new_total_quantity: @new_total_quantity,
        replenishment_source: @replenishment_source,
        replenished_by: @replenished_by
      )
    end
  end

  # Event fired when reservation expires
  class ReservationExpired < BaseEvent
    attr_reader :expired_amount, :order_id, :original_reservation_time, :expired_by

    # Initialize reservation expiration event
    # @param aggregate_id [String] inventory aggregate ID
    # @param expired_amount [Integer] amount that expired
    # @param order_id [String] ID of the order with expired reservation
    # @param original_reservation_time [Time] when reservation was created
    # @param expired_by [String] user/system that expired the reservation
    def initialize(aggregate_id, expired_amount, order_id: nil, original_reservation_time: nil, expired_by: 'system')
      super(aggregate_id, metadata: { expired_by: expired_by })
      @expired_amount = expired_amount
      @order_id = order_id
      @original_reservation_time = original_reservation_time
      @expired_by = expired_by
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        expired_amount: @expired_amount,
        order_id: @order_id,
        original_reservation_time: @original_reservation_time,
        expired_by: @expired_by
      )
    end
  end

  # Event fired when inventory threshold is adjusted
  class ThresholdAdjusted < BaseEvent
    attr_reader :old_threshold, :new_threshold, :threshold_type, :adjusted_by, :reason

    # Initialize threshold adjustment event
    # @param aggregate_id [String] inventory aggregate ID
    # @param old_threshold [Integer] previous threshold value
    # @param new_threshold [Integer] new threshold value
    # @param threshold_type [Symbol] type of threshold being adjusted
    # @param adjusted_by [String] user/system making the adjustment
    # @param reason [String] reason for the adjustment
    def initialize(aggregate_id, old_threshold, new_threshold, threshold_type: :low_stock, adjusted_by: nil, reason: nil)
      super(aggregate_id, metadata: { adjusted_by: adjusted_by })
      @old_threshold = old_threshold
      @new_threshold = new_threshold
      @threshold_type = threshold_type
      @adjusted_by = adjusted_by
      @reason = reason
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        old_threshold: @old_threshold,
        new_threshold: @new_threshold,
        threshold_type: @threshold_type,
        adjusted_by: @adjusted_by,
        reason: @reason
      )
    end
  end

  # Event fired when inventory audit is performed
  class InventoryAudited < BaseEvent
    attr_reader :audited_quantity, :system_quantity, :discrepancy, :audited_by, :audit_notes

    # Initialize inventory audit event
    # @param aggregate_id [String] inventory aggregate ID
    # @param audited_quantity [Integer] quantity found during audit
    # @param system_quantity [Integer] quantity recorded in system
    # @param audited_by [String] user/system performing audit
    # @param audit_notes [String] notes from the audit
    def initialize(aggregate_id, audited_quantity, system_quantity, audited_by: nil, audit_notes: nil)
      super(aggregate_id, metadata: { audited_by: audited_by })
      @audited_quantity = audited_quantity
      @system_quantity = system_quantity
      @discrepancy = audited_quantity - system_quantity
      @audited_by = audited_by
      @audit_notes = audit_notes
    end

    # Convert to hash for serialization
    # @return [Hash] serializable event data
    def to_h
      super.merge(
        audited_quantity: @audited_quantity,
        system_quantity: @system_quantity,
        discrepancy: @discrepancy,
        audited_by: @audited_by,
        audit_notes: @audit_notes
      )
    end
  end
end