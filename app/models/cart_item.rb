# frozen_string_literal: true

# == Schema Information
#
# Table name: cart_items
#
#  id                :bigint           not null, primary key
#  user_id           :bigint           not null, indexed
#  item_id           :bigint           not null, indexed
#  quantity          :integer          not null, default(1)
#  unit_price        :decimal(10,2)    not null, indexed
#  total_price       :decimal(10,2)    not null, indexed
#  locked_at         :datetime         indexed
#  expires_at        :datetime         not null, indexed
#  metadata          :jsonb            default({}), indexed
#  state             :string           default("active"), indexed
#  version           :integer          default(1)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes:
#  cart_items_user_item_unique    (user_id, item_id) UNIQUE
#  cart_items_expires_at_index    (expires_at)
#  cart_items_locked_at_index     (locked_at)
#  cart_items_metadata_gin        (metadata) USING gin
#  cart_items_state_index         (state)
#  cart_items_total_price_index   (total_price)
#  cart_items_unit_price_index    (unit_price)
#  cart_items_user_id_index       (user_id)
#  cart_items_item_id_index       (item_id)
#
# Foreign Keys:
#  fk_rails_cart_items_user_id  (user_id => users.id)
#  fk_rails_cart_items_item_id  (item_id => items.id)
#

# Enterprise-grade Cart Item Aggregate Root
# Implements Domain-Driven Design patterns with sophisticated business logic encapsulation
# Thread-safe, horizontally scalable, and audit-compliant cart management
class CartItem < ApplicationRecord
  include CartItemStateMachine
  include CartItemConcurrencyControl
  include CartItemAuditTrail
  include CartItemBusinessRules

  # === Domain Constants ===
  MAX_QUANTITY = 999
  MIN_QUANTITY = 1
  CART_ITEM_TTL = 30.days
  LOCK_TIMEOUT = 5.minutes

  # === Associations ===
  belongs_to :user, class_name: 'User', inverse_of: :cart_items
  belongs_to :item, class_name: 'Item', inverse_of: :cart_items

  # === Advanced Validations ===
  validates :quantity, presence: true,
                      numericality: {
                        greater_than_or_equal_to: MIN_QUANTITY,
                        less_than_or_equal_to: MAX_QUANTITY,
                        only_integer: true
                      }

  validates :unit_price, presence: true,
                        numericality: {
                          greater_than: 0,
                          precision: 10,
                          scale: 2
                        }

  validates :total_price, presence: true,
                         numericality: {
                           greater_than_or_equal_to: 0,
                           precision: 10,
                           scale: 2
                         }

  validates :state, presence: true,
                   inclusion: { in: CartItemStates::ALL_STATES }

  validates :expires_at, presence: true,
                        timeliness: { after: :created_at }

  validate :business_logic_compliance
  validate :inventory_availability
  validate :pricing_consistency

  # === Advanced Scopes ===
  scope :active, -> { where(state: CartItemStates::ACTIVE) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :locked, -> { where.not(locked_at: nil) }
  scope :available_for_purchase, -> { active.where('expires_at > ?', Time.current) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_item, ->(item_id) { where(item_id: item_id) }
  scope :high_value, ->(threshold = 1000) { where('total_price >= ?', threshold) }
  scope :recently_updated, -> { order(updated_at: :desc) }
  scope :expiring_soon, ->(hours = 24) {
    where('expires_at BETWEEN ? AND ?', Time.current, Time.current + hours.hours)
  }

  # === Callbacks ===
  before_validation :set_default_values, on: :create
  before_validation :calculate_total_price
  before_save :update_version
  after_create :publish_creation_event
  after_update :publish_update_event, if: :saved_changes?
  after_destroy :publish_deletion_event

  # === Domain Methods ===

  # Atomically adds quantity with optimistic locking
  # @param additional_quantity [Integer] quantity to add
  # @return [Result] Success/Failure with updated cart item or error details
  def add_quantity(additional_quantity)
    with_optimistic_lock do
      self.quantity += additional_quantity
      save_with_validation!
      Success(self)
    end
  rescue ActiveRecord::StaleObjectError
    Failure(CartItemConcurrencyError.new("Cart item was modified by another process"))
  rescue ValidationError => e
    Failure(e)
  end

  # Atomically removes quantity with business rule validation
  # @param removal_quantity [Integer] quantity to remove
  # @return [Result] Success/Failure with updated cart item or error details
  def remove_quantity(removal_quantity)
    with_optimistic_lock do
      raise CartItemBusinessRuleError.new("Cannot remove more than current quantity") if removal_quantity > quantity

      self.quantity -= removal_quantity
      return destroy_with_audit! if quantity.zero?

      save_with_validation!
      Success(self)
    end
  rescue ActiveRecord::StaleObjectError
    Failure(CartItemConcurrencyError.new("Cart item was modified by another process"))
  rescue CartItemBusinessRuleError => e
    Failure(e)
  end

  # Calculates subtotal with precision handling and business rules
  # @return [BigDecimal] calculated subtotal with proper precision
  def subtotal
    PriceCalculator.calculate(unit_price, quantity, item.discount_rules)
  rescue CalculationError => e
    CartItemLogger.error("Price calculation failed for cart_item_#{id}", e)
    raise CartItemBusinessRuleError.new("Unable to calculate pricing")
  end

  # Checks if cart item is eligible for purchase
  # @return [Boolean] true if item can be purchased
  def purchasable?
    active? && !expired? && item_available_for_purchase? && pricing_valid?
  end

  # Extends cart item expiration with business rule validation
  # @param extension_hours [Integer] hours to extend
  # @return [Result] Success/Failure with updated expiration or error details
  def extend_expiry(extension_hours)
    with_optimistic_lock do
      new_expiry = expires_at + extension_hours.hours
      max_expiry = created_at + CART_ITEM_TTL

      raise CartItemBusinessRuleError.new("Cannot extend beyond maximum TTL") if new_expiry > max_expiry

      update_with_validation!(expires_at: new_expiry)
      Success(self)
    end
  rescue ActiveRecord::StaleObjectError
    Failure(CartItemConcurrencyError.new("Cart item was modified by another process"))
  rescue CartItemBusinessRuleError => e
    Failure(e)
  end

  # Reserves inventory for this cart item
  # @return [Result] Success/Failure with reservation details or error
  def reserve_inventory
    InventoryReservationService.reserve(item, quantity, expires_at)
  rescue InventoryError => e
    Failure(e)
  end

  # Releases reserved inventory
  # @return [Result] Success/Failure with release confirmation
  def release_inventory
    InventoryReservationService.release(item, quantity)
  rescue InventoryError => e
    CartItemLogger.error("Failed to release inventory for cart_item_#{id}", e)
    Failure(e)
  end

  # === Private Methods ===

  private

  # Sets intelligent default values based on business rules
  def set_default_values
    self.state ||= CartItemStates::ACTIVE
    self.expires_at ||= CART_ITEM_TTL.from_now
    self.unit_price ||= item&.price || 0
    self.quantity ||= MIN_QUANTITY
    self.metadata ||= {}
  end

  # Calculates total price with business logic and precision
  def calculate_total_price
    calculated_total = subtotal
    self.total_price = calculated_total
  rescue CalculationError => e
    CartItemLogger.error("Total price calculation failed for cart_item_#{id}", e)
    errors.add(:total_price, "calculation failed")
  end

  # Validates business logic compliance
  def business_logic_compliance
    return if BusinessRuleEngine.validate_cart_item(self).success?

    BusinessRuleEngine.validate_cart_item(self).errors.each do |error|
      errors.add(error.field, error.message)
    end
  end

  # Validates inventory availability
  def inventory_availability
    return if InventoryValidator.available?(item, quantity)

    errors.add(:quantity, "exceeds available inventory")
  end

  # Validates pricing consistency
  def pricing_consistency
    return if PricingValidator.consistent?(unit_price, total_price, quantity)

    errors.add(:total_price, "inconsistent with unit price and quantity")
  end

  # Publishes domain events
  def publish_creation_event
    EventPublisher.publish('cart_item.created', self)
  end

  def publish_update_event
    EventPublisher.publish('cart_item.updated', self, saved_changes)
  end

  def publish_deletion_event
    EventPublisher.publish('cart_item.deleted', self)
  end

  # Updates version for optimistic locking
  def update_version
    self.version += 1 if persisted?
  end

  # Saves with enhanced validation and error handling
  def save_with_validation!
    save!
  rescue ActiveRecord::RecordInvalid => e
    raise ValidationError.new(e.record.errors.full_messages)
  rescue ActiveRecord::RecordNotUnique => e
    raise CartItemConcurrencyError.new("Cart item already exists for this user and item")
  end

  # Updates with enhanced validation and error handling
  def update_with_validation!(attributes)
    update!(attributes)
  rescue ActiveRecord::RecordInvalid => e
    raise ValidationError.new(e.record.errors.full_messages)
  end

  # Destroys with audit trail
  def destroy_with_audit!
    audit_destroy
    destroy!
  end
end
