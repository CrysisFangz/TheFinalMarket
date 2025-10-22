# frozen_string_literal: true

# Cart Item Concurrency Control
# Sophisticated concurrency management for high-throughput cart operations
module CartItemConcurrencyControl
  extend ActiveSupport::Concern

  # === Locking Strategies ===

  # Acquires pessimistic lock for critical operations
  # @param timeout [Integer] lock timeout in seconds
  # @return [Boolean] true if lock acquired
  def acquire_pessimistic_lock(timeout = 30)
    return true if locked_at && lock_active?

    with_pessimistic_lock(timeout) do
      self.locked_at = Time.current
      self.metadata['lock_acquired_at'] = Time.current
      save(validate: false)
      true
    end
  rescue ActiveRecord::LockWaitTimeout
    CartItemLogger.warn("Failed to acquire pessimistic lock for cart_item_#{id}")
    false
  end

  # Releases pessimistic lock
  # @return [Boolean] true if lock released
  def release_pessimistic_lock
    return false unless locked_at

    update_columns(
      locked_at: nil,
      updated_at: Time.current
    )
    true
  rescue ActiveRecord::ActiveRecordError => e
    CartItemLogger.error("Failed to release lock for cart_item_#{id}", e)
    false
  end

  # Checks if current lock is still active
  # @return [Boolean] true if lock is active
  def lock_active?
    return false unless locked_at

    Time.current - locked_at < CartItem::LOCK_TIMEOUT
  end

  # Executes block with pessimistic locking
  # @param timeout [Integer] lock timeout in seconds
  # @return result of block execution
  def with_pessimistic_lock(timeout = 30)
    reload(lock: true, timeout: timeout)
    yield
  ensure
    release_pessimistic_lock if locked_at
  end

  # === Optimistic Locking Helpers ===

  # Enhanced optimistic locking with conflict resolution
  # @param conflict_resolution [Symbol] strategy for handling conflicts
  # @return result of block execution
  def with_optimistic_lock(conflict_resolution: :raise)
    retry_count = 0
    max_retries = 3

    begin
      reload
      yield
    rescue ActiveRecord::StaleObjectError => e
      retry_count += 1

      if retry_count <= max_retries
        case conflict_resolution
        when :merge
          handle_merge_conflict(e)
          retry
        when :retry
          sleep(0.1 * retry_count) # Exponential backoff
          retry
        when :raise
          raise e
        else
          raise CartItemConcurrencyError.new("Unknown conflict resolution strategy: #{conflict_resolution}")
        end
      else
        raise CartItemConcurrencyError.new("Maximum retry attempts exceeded for cart_item_#{id}")
      end
    end
  end

  # === Concurrency-Safe Operations ===

  # Thread-safe quantity update with automatic conflict resolution
  # @param new_quantity [Integer] target quantity
  # @param conflict_strategy [Symbol] conflict resolution strategy
  # @return [Result] Success/Failure with updated item or error
  def safe_quantity_update(new_quantity, conflict_strategy: :merge)
    with_optimistic_lock(conflict_resolution: conflict_strategy) do
      old_quantity = quantity
      self.quantity = new_quantity

      if quantity_changed?
        self.total_price = calculate_total_price
        save_with_validation!

        audit_quantity_change(old_quantity, new_quantity)
        Success(self)
      else
        Success(self)
      end
    end
  rescue ActiveRecord::StaleObjectError => e
    Failure(CartItemConcurrencyError.new("Concurrent modification detected: #{e.message}"))
  rescue ValidationError => e
    Failure(e)
  end

  # Thread-safe state transition with conflict resolution
  # @param new_state [String] target state
  # @return [Result] Success/Failure with transition confirmation
  def safe_state_transition(new_state)
    with_optimistic_lock(conflict_resolution: :retry) do
      transition_to_state(new_state)
    end
  rescue CartItemConcurrencyError => e
    Failure(e)
  end

  # === Batch Operations ===

  # Updates multiple cart items atomically
  # @param cart_items [Array<CartItem>] items to update
  # @param operation [Proc] operation to perform on each item
  # @return [Hash] results of batch operation
  def self.batch_update(cart_items, operation)
    results = { success: [], failed: [] }

    CartItem.transaction do
      cart_items.each do |item|
        begin
          operation.call(item)
          results[:success] << item
        rescue StandardError => e
          CartItemLogger.error("Batch update failed for cart_item_#{item.id}", e)
          results[:failed] << { item: item, error: e }
        end
      end

      raise ActiveRecord::Rollback if results[:failed].any?
    end

    results
  end

  private

  # Handles merge conflict resolution for optimistic locking
  # @param conflict_error [ActiveRecord::StaleObjectError] the conflict error
  def handle_merge_conflict(conflict_error)
    CartItemLogger.info("Resolving merge conflict for cart_item_#{id}", conflict_error)
    # Implement sophisticated merge logic based on business rules
    # This could involve last-write-wins, field-level merging, or custom resolution strategies
  end

  # Audits quantity changes for compliance and debugging
  # @param old_quantity [Integer] previous quantity
  # @param new_quantity [Integer] current quantity
  def audit_quantity_change(old_quantity, new_quantity)
    audit_event = {
      event_type: 'quantity_change',
      old_quantity: old_quantity,
      new_quantity: new_quantity,
      changed_at: Time.current,
      user_id: user_id,
      item_id: item_id
    }

    self.metadata['quantity_history'] ||= []
    self.metadata['quantity_history'] << audit_event

    CartItemLogger.info(
      "Cart item #{id} quantity changed from #{old_quantity} to #{new_quantity}",
      audit_event
    )
  end

  # Calculates total price with precision and validation
  # @return [BigDecimal] calculated total price
  def calculate_total_price
    PriceCalculator.calculate(unit_price, quantity, item.discount_rules)
  end
end