# frozen_string_literal: true

# Cart Item State Machine
# Sophisticated state management with business rule validation and audit trails
module CartItemStateMachine
  extend ActiveSupport::Concern

  included do
    # === State Transition Methods ===

    # Transitions to locked state for purchase processing
    # @param lock_duration [Integer] duration in minutes to lock the item
    # @return [Result] Success/Failure with updated state or error details
    def lock_for_purchase(lock_duration = 5)
      transition_to_state(CartItemStates::LOCKED, lock_duration.minutes.from_now)
    end

    # Transitions to purchased state after successful payment
    # @return [Result] Success/Failure with purchase confirmation
    def mark_as_purchased
      transition_to_state(CartItemStates::PURCHASED)
    end

    # Transitions to cancelled state
    # @param reason [String] reason for cancellation
    # @return [Result] Success/Failure with cancellation confirmation
    def cancel(reason = nil)
      transition_to_state(CartItemStates::CANCELLED) do
        self.metadata['cancellation_reason'] = reason if reason
        self.metadata['cancelled_at'] = Time.current
      end
    end

    # Transitions to expired state when TTL is reached
    # @return [Result] Success/Failure with expiration confirmation
    def expire
      transition_to_state(CartItemStates::EXPIRED) do
        self.metadata['expired_at'] = Time.current
        release_inventory if persisted?
      end
    end

    # Transitions to abandoned state for cleanup
    # @return [Result] Success/Failure with abandonment confirmation
    def abandon
      transition_to_state(CartItemStates::ABANDONED) do
        self.metadata['abandoned_at'] = Time.current
        release_inventory if persisted?
      end
    end

    # === State Query Methods ===

    # @return [Boolean] true if item is in active state
    def active?
      state == CartItemStates::ACTIVE
    end

    # @return [Boolean] true if item is in locked state
    def locked?
      state == CartItemStates::LOCKED
    end

    # @return [Boolean] true if item is in expired state
    def expired?
      state == CartItemStates::EXPIRED
    end

    # @return [Boolean] true if item is in cancelled state
    def cancelled?
      state == CartItemStates::CANCELLED
    end

    # @return [Boolean] true if item is in purchased state
    def purchased?
      state == CartItemStates::PURCHASED
    end

    # @return [Boolean] true if item is in abandoned state
    def abandoned?
      state == CartItemStates::ABANDONED
    end

    # @return [Boolean] true if item can be purchased
    def purchasable?
      CartItemStates.purchasable?(state) && !expired?
    end

    # @return [Boolean] true if item state can be changed
    def can_change_state?
      CartItemStates.mutable?(state)
    end

    # === State Management ===

    # Core state transition method with validation and audit
    # @param new_state [String] target state
    # @param lock_until [Time] when to unlock if transitioning to locked
    # @return [Result] Success/Failure with transition details
    def transition_to_state(new_state, lock_until = nil)
      return Failure(CartItemBusinessRuleError.new("Cannot change state from #{state}")) unless can_change_state?

      unless CartItemStates.valid_transition?(state, new_state)
        return Failure(CartItemBusinessRuleError.new("Invalid state transition from #{state} to #{new_state}"))
      end

      with_optimistic_lock do
        old_state = state
        self.state = new_state

        if new_state == CartItemStates::LOCKED && lock_until
          self.locked_at = Time.current
          self.metadata['lock_timeout'] = lock_until
        end

        yield if block_given?

        save_with_validation!

        audit_state_change(old_state, new_state)
        Success(self)
      end
    rescue ActiveRecord::StaleObjectError
      Failure(CartItemConcurrencyError.new("Cart item state was modified by another process"))
    rescue ValidationError => e
      Failure(e)
    rescue CartItemBusinessRuleError => e
      Failure(e)
    end

    # Automatic state management based on business rules
    def manage_state
      case state
      when CartItemStates::LOCKED
        handle_locked_state
      when CartItemStates::ACTIVE
        handle_active_state
      end
    end

    private

    # Handles logic for locked state
    def handle_locked_state
      return unless locked? && lock_expired?

      CartItemStateManager.expire_lock(self)
    end

    # Handles logic for active state
    def handle_active_state
      return unless expired?

      CartItemStateManager.expire_item(self)
    end

    # Checks if lock has expired
    # @return [Boolean] true if lock has expired
    def lock_expired?
      return false unless locked_at && metadata['lock_timeout']

      Time.current > metadata['lock_timeout']
    end

    # Audits state changes for compliance and debugging
    # @param old_state [String] previous state
    # @param new_state [String] current state
    def audit_state_change(old_state, new_state)
      audit_event = {
        event_type: 'state_transition',
        old_state: old_state,
        new_state: new_state,
        transitioned_at: Time.current,
        user_id: user_id,
        item_id: item_id
      }

      self.metadata['state_history'] ||= []
      self.metadata['state_history'] << audit_event

      CartItemLogger.info(
        "Cart item #{id} state transitioned from #{old_state} to #{new_state}",
        audit_event
      )
    end

    # Enhanced save with state validation
    def save_with_validation!
      validate_state_transition if state_changed?
      super
    end

    # Validates state transition business rules
    def validate_state_transition
      case state
      when CartItemStates::PURCHASED
        validate_purchase_transition
      when CartItemStates::CANCELLED
        validate_cancellation_transition
      end
    end

    # Validates purchase transition rules
    def validate_purchase_transition
      unless purchasable?
        raise CartItemBusinessRuleError.new("Cannot purchase item in #{state} state")
      end

      unless inventory_available?
        raise CartItemBusinessRuleError.new("Insufficient inventory for purchase")
      end
    end

    # Validates cancellation transition rules
    def validate_cancellation_transition
      if purchased?
        raise CartItemBusinessRuleError.new("Cannot cancel already purchased item")
      end
    end

    # Checks if inventory is available for purchase
    # @return [Boolean] true if inventory is sufficient
    def inventory_available?
      InventoryValidator.available?(item, quantity)
    end
  end

  # === Class Methods ===

  module ClassMethods
    # Finds cart items that need state management
    # @return [ActiveRecord::Relation] items requiring attention
    def requiring_state_management
      where(state: [CartItemStates::LOCKED, CartItemStates::ACTIVE])
        .where('expires_at < ? OR locked_at < ?', Time.current, Time.current)
    end

    # Bulk state transition for performance
    # @param cart_item_ids [Array<Integer>] IDs of items to transition
    # @param new_state [String] target state
    # @return [Hash] results of bulk operation
    def bulk_transition(cart_item_ids, new_state)
      CartItemStateManager.bulk_transition(cart_item_ids, new_state)
    end
  end
end