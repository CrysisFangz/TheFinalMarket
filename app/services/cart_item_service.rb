# frozen_string_literal: true

# Cart Item Service
# Domain service for orchestrating complex cart item operations
# Follows Domain-Driven Design patterns with sophisticated business logic coordination
class CartItemService
  include ServicePattern
  include BusinessRuleValidation
  include ErrorHandling
  include EventPublishing

  # === Cart Item Creation ===

  # Creates a new cart item with comprehensive validation and business rules
  # @param user [User] user adding the item
  # @param item [Item] item to add to cart
  # @param quantity [Integer] quantity to add
  # @param options [Hash] additional options (pricing, metadata, etc.)
  # @return [Result] Success/Failure with created cart item or error details
  def create_cart_item(user, item, quantity, options = {})
    with_error_handling do
      validate_creation_params(user, item, quantity, options)

      # Check business rules before creation
      business_rule_result = validate_business_rules(user, item, quantity)
      return business_rule_result if business_rule_result.failure?

      # Begin transaction for atomicity
      cart_item = nil
      transaction do
        # Create cart item with calculated pricing
        pricing_result = calculate_pricing(item, quantity, options)
        return pricing_result if pricing_result.failure?

        # Create cart item
        cart_item = build_cart_item(user, item, quantity, pricing_result.value!, options)
        cart_item.save!
        cart_item.audit_creation(options)

        # Reserve inventory if required
        reserve_inventory(cart_item) if options[:reserve_inventory]

        # Publish creation event
        publish_event('cart_item.created', cart_item)
      end

      Success(cart_item)
    end
  rescue ServiceError => e
    handle_service_error(e)
  end

  # === Cart Item Updates ===

  # Updates cart item quantity with sophisticated conflict resolution
  # @param cart_item [CartItem] item to update
  # @param new_quantity [Integer] new quantity
  # @param options [Hash] update options
  # @return [Result] Success/Failure with updated item or error details
  def update_quantity(cart_item, new_quantity, options = {})
    with_error_handling do
      validate_quantity_update(cart_item, new_quantity)

      # Use optimistic locking for concurrent safety
      cart_item.with_optimistic_lock do
        old_quantity = cart_item.quantity

        # Validate business rules for new quantity
        rule_result = validate_quantity_business_rules(cart_item, new_quantity)
        return rule_result if rule_result.failure?

        # Calculate new pricing
        pricing_result = recalculate_pricing(cart_item, new_quantity)
        return pricing_result if pricing_result.failure?

        # Update cart item
        cart_item.quantity = new_quantity
        cart_item.total_price = pricing_result.value!
        cart_item.save!

        # Handle inventory changes
        handle_inventory_changes(cart_item, old_quantity, new_quantity)

        # Audit and publish events
        cart_item.audit_update(quantity: [old_quantity, new_quantity])
        publish_event('cart_item.quantity_updated', cart_item, { old_quantity: old_quantity, new_quantity: new_quantity })

        Success(cart_item)
      end
    end
  rescue ServiceError => e
    handle_service_error(e)
  end

  # === Cart Item Removal ===

  # Removes cart item with comprehensive cleanup
  # @param cart_item [CartItem] item to remove
  # @param reason [String] reason for removal
  # @return [Result] Success/Failure with removal confirmation
  def remove_cart_item(cart_item, reason = 'user_requested')
    with_error_handling do
      transaction do
        # Release reserved inventory
        cart_item.release_inventory if cart_item.persisted?

        # Audit before deletion
        cart_item.audit_deletion(reason)

        # Remove cart item
        cart_item.destroy!

        # Publish removal event
        publish_event('cart_item.removed', cart_item, { reason: reason })

        Success(true)
      end
    end
  rescue ServiceError => e
    handle_service_error(e)
  end

  # === Bulk Operations ===

  # Performs bulk operations on multiple cart items
  # @param user [User] user whose items to operate on
  # @param item_ids [Array<Integer>] IDs of items to operate on
  # @param operation [Symbol] operation to perform (:remove, :expire, :lock)
  # @return [Result] Success/Failure with operation results
  def bulk_operation(user, item_ids, operation)
    with_error_handling do
      case operation
      when :remove
        bulk_remove(user, item_ids)
      when :expire
        bulk_expire(user, item_ids)
      when :lock
        bulk_lock(user, item_ids)
      else
        raise InvalidOperationError.new("Unsupported bulk operation: #{operation}")
      end
    end
  rescue ServiceError => e
    handle_service_error(e)
  end

  # === Advanced Operations ===

  # Processes cart item for purchase with comprehensive validation
  # @param cart_item [CartItem] item to purchase
  # @param payment_method [String] payment method identifier
  # @return [Result] Success/Failure with purchase processing details
  def process_purchase(cart_item, payment_method)
    with_error_handling do
      validate_purchase_eligibility(cart_item)

      transaction do
        # Lock item for purchase processing
        lock_result = cart_item.lock_for_purchase
        return lock_result if lock_result.failure?

        # Validate final state
        final_validation = validate_final_purchase_state(cart_item)
        return final_validation if final_validation.failure?

        # Process payment
        payment_result = process_payment(cart_item, payment_method)
        return payment_result if payment_result.failure?

        # Complete purchase
        cart_item.mark_as_purchased
        cart_item.save!

        # Release inventory and publish events
        finalize_purchase(cart_item, payment_result.value!)

        Success(cart_item)
      end
    end
  rescue ServiceError => e
    handle_service_error(e)
  end

  # === Cart Management ===

  # Cleans up expired cart items for a user
  # @param user [User] user whose cart to clean
  # @return [Result] Success/Failure with cleanup summary
  def cleanup_expired_items(user)
    with_error_handling do
      expired_items = user.cart_items.expired

      cleanup_results = {
        processed: 0,
        removed: 0,
        errors: []
      }

      expired_items.find_each do |item|
        begin
          remove_cart_item(item, 'expired')
          cleanup_results[:removed] += 1
        rescue ServiceError => e
          cleanup_results[:errors] << { item_id: item.id, error: e.message }
        ensure
          cleanup_results[:processed] += 1
        end
      end

      publish_event('cart_items.cleanup_completed', user, cleanup_results)

      if cleanup_results[:errors].any?
        PartialSuccess(cleanup_results)
      else
        Success(cleanup_results)
      end
    end
  rescue ServiceError => e
    handle_service_error(e)
  end

  private

  # === Validation Methods ===

  def validate_creation_params(user, item, quantity, options)
    raise ValidationError.new('User is required') unless user
    raise ValidationError.new('Item is required') unless item
    raise ValidationError.new('Quantity must be positive') unless quantity&.positive?
  end

  def validate_quantity_update(cart_item, new_quantity)
    unless cart_item.can_change_state?
      raise BusinessRuleError.new('Cart item cannot be modified in current state')
    end

    unless new_quantity&.positive?
      raise ValidationError.new('Quantity must be positive')
    end
  end

  def validate_purchase_eligibility(cart_item)
    unless cart_item.purchasable?
      raise BusinessRuleError.new('Cart item is not eligible for purchase')
    end
  end

  def validate_final_purchase_state(cart_item)
    # Final validation before purchase
    unless cart_item.locked?
      raise BusinessRuleError.new('Cart item must be locked for purchase')
    end

    unless cart_item.check_inventory_availability.success?
      raise BusinessRuleError.new('Insufficient inventory for purchase')
    end

    Success(true)
  end

  # === Business Logic Methods ===

  def validate_business_rules(user, item, quantity)
    CartItemBusinessRules.can_add_to_cart?(user, item, quantity)
  end

  def validate_quantity_business_rules(cart_item, new_quantity)
    context = CartItemBusinessRules::BusinessRuleContext.new(
      user: cart_item.user,
      item: cart_item.item,
      quantity: new_quantity,
      cart_item: cart_item
    )

    BusinessRuleEngine::QuantityLimitRule.validate(context)
  end

  # === Pricing Methods ===

  def calculate_pricing(item, quantity, options)
    PricingCalculator.calculate(
      item: item,
      quantity: quantity,
      user: options[:user],
      promo_code: options[:promo_code],
      user_context: options[:user_context]
    )
  end

  def recalculate_pricing(cart_item, new_quantity)
    calculate_pricing(cart_item.item, new_quantity, { user: cart_item.user })
  end

  # === Inventory Methods ===

  def reserve_inventory(cart_item)
    cart_item.reserve_inventory
  end

  def handle_inventory_changes(cart_item, old_quantity, new_quantity)
    quantity_diff = new_quantity - old_quantity

    if quantity_diff > 0
      # Increased quantity - reserve additional inventory
      cart_item.reserve_inventory if quantity_diff > 0
    elsif quantity_diff < 0
      # Decreased quantity - release inventory
      release_amount = -quantity_diff
      InventoryReservationService.release(cart_item.item, release_amount)
    end
  end

  # === Payment Methods ===

  def process_payment(cart_item, payment_method)
    PaymentService.process_purchase(
      cart_item: cart_item,
      payment_method: payment_method,
      amount: cart_item.total_price
    )
  end

  # === Finalization Methods ===

  def finalize_purchase(cart_item, payment_result)
    # Release reserved inventory
    cart_item.release_inventory

    # Publish purchase completion events
    publish_event('cart_item.purchased', cart_item, payment_result)

    # Trigger post-purchase workflows
    trigger_post_purchase_workflows(cart_item)
  end

  def trigger_post_purchase_workflows(cart_item)
    # Trigger notification workflows
    NotificationService.cart_item_purchased(cart_item)

    # Trigger inventory workflows
    InventoryService.update_after_purchase(cart_item)

    # Trigger analytics workflows
    AnalyticsService.track_purchase(cart_item)
  end

  # === Bulk Operation Methods ===

  def bulk_remove(user, item_ids)
    items = user.cart_items.where(id: item_ids)
    results = { success: [], failed: [] }

    items.find_each do |item|
      result = remove_cart_item(item, 'bulk_operation')
      if result.success?
        results[:success] << item.id
      else
        results[:failed] << { id: item.id, error: result.failure }
      end
    end

    results
  end

  def bulk_expire(user, item_ids)
    CartItem.where(user: user, id: item_ids).update_all(
      state: CartItemStates::EXPIRED,
      updated_at: Time.current
    )

    { expired_count: item_ids.count }
  end

  def bulk_lock(user, item_ids)
    CartItem.where(user: user, id: item_ids).find_each do |item|
      item.lock_for_purchase
    end

    { locked_count: item_ids.count }
  end

  # === Error Handling ===

  def handle_service_error(error)
    CartItemLogger.error("CartItemService error: #{error.message}", error.context)
    Failure(error)
  end

  def with_error_handling
    yield
  rescue ValidationError => e
    Failure(ValidationError.new(e.message))
  rescue BusinessRuleError => e
    Failure(BusinessRuleError.new(e.message))
  rescue ActiveRecord::ActiveRecordError => e
    Failure(DatabaseError.new(e.message))
  rescue StandardError => e
    Failure(UnexpectedError.new(e.message))
  end
end