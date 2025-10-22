# frozen_string_literal: true

# Immutable value object representing inventory quantity
# Encapsulates all business logic related to quantity validation and calculations
class Quantity
  attr_reader :value, :reserved, :allocated_at

  # Maximum safe integer value for quantity to prevent overflow issues
  MAX_SAFE_INTEGER = 2_147_483_647
  MINIMUM_QUANTITY = 0

  # Create a new quantity value object
  # @param value [Integer] total quantity available
  # @param reserved [Integer] quantity currently reserved
  # @param allocated_at [Time] when the quantity was last allocated
  def initialize(value, reserved: 0, allocated_at: nil)
    validate_quantity_value(value)
    validate_reserved_quantity(reserved, value)

    @value = value
    @reserved = reserved
    @allocated_at = allocated_at || Time.current
    freeze # Make immutable
  end

  # Available quantity (total - reserved)
  # @return [Integer] available quantity for new allocations
  def available
    @value - @reserved
  end

  # Check if quantity is available for allocation
  # @param amount [Integer] amount to check availability for
  # @return [Boolean] true if amount is available
  def available?(amount)
    available >= amount && amount > 0
  end

  # Check if inventory is in stock
  # @return [Boolean] true if any quantity is available
  def in_stock?
    available > 0
  end

  # Check if inventory is out of stock
  # @return [Boolean] true if no quantity is available
  def out_of_stock?
    available.zero?
  end

  # Reserve additional quantity
  # @param amount [Integer] amount to reserve
  # @return [Quantity] new quantity with updated reservation
  def reserve(amount)
    raise ArgumentError, 'Cannot reserve negative amount' if amount.negative?
    raise InsufficientQuantityError, 'Insufficient available quantity' unless available?(amount)

    Quantity.new(@value, reserved: @reserved + amount)
  end

  # Release reserved quantity
  # @param amount [Integer] amount to release (maximum of current reservation)
  # @return [Quantity] new quantity with reduced reservation
  def release(amount)
    raise ArgumentError, 'Cannot release negative amount' if amount.negative?

    actual_release = [amount, @reserved].min
    Quantity.new(@value, reserved: @reserved - actual_release)
  end

  # Allocate quantity (reduce total and reserved)
  # @param amount [Integer] amount to allocate
  # @return [Quantity] new quantity with reduced total and reserved
  def allocate(amount)
    raise ArgumentError, 'Cannot allocate negative amount' if amount.negative?
    raise InsufficientQuantityError, 'Insufficient total quantity' if @value < amount

    # Release from reserved if possible, otherwise reduce total
    if @reserved >= amount
      Quantity.new(@value, reserved: @reserved - amount)
    else
      remaining_from_total = amount - @reserved
      Quantity.new(@value - remaining_from_total, reserved: 0)
    end
  end

  # Add to total quantity
  # @param amount [Integer] amount to add
  # @return [Quantity] new quantity with increased total
  def add(amount)
    raise ArgumentError, 'Cannot add negative amount' if amount.negative?

    Quantity.new(@value + amount, reserved: @reserved)
  end

  # Calculate utilization rate as percentage
  # @return [Float] utilization percentage (0.0 to 1.0)
  def utilization_rate
    return 0.0 if @value.zero?

    @reserved.to_f / @value
  end

  # Calculate stock turnover rate
  # @param time_window [ActiveSupport::Duration] time period for calculation
  # @return [Float] turnover rate per time window
  def turnover_rate(time_window)
    return 0.0 if @value.zero? || time_window.zero?

    # This would typically use historical data to calculate actual turnover
    # For now, return a theoretical rate based on current state
    allocation_rate = (@value - available).to_f / @value
    allocation_rate / time_window.to_f
  end

  # Equality comparison
  # @param other [Quantity] quantity to compare with
  # @return [Boolean] true if quantities are equal
  def ==(other)
    other.is_a?(Quantity) && @value == other.value && @reserved == other.reserved
  end

  alias eql? ==

  # Hash for use in hash-based collections
  # @return [Integer] hash code
  def hash
    [@value, @reserved].hash
  end

  # String representation for debugging
  # @return [String] formatted string
  def to_s
    "Quantity(#{@value}, reserved: #{@reserved}, available: #{available})"
  end

  # Convert to hash for serialization
  # @return [Hash] serializable hash
  def to_h
    {
      value: @value,
      reserved: @reserved,
      available: available,
      allocated_at: @allocated_at,
      utilization_rate: utilization_rate
    }
  end

  private

  # Validate that quantity value is within acceptable bounds
  # @param value [Integer] quantity value to validate
  # @raise [ArgumentError] if value is invalid
  def validate_quantity_value(value)
    raise ArgumentError, 'Quantity must be an integer' unless value.is_a?(Integer)
    raise ArgumentError, 'Quantity cannot be negative' if value.negative?
    raise ArgumentError, 'Quantity exceeds maximum safe value' if value > MAX_SAFE_INTEGER
  end

  # Validate that reserved quantity is valid for the total quantity
  # @param reserved [Integer] reserved quantity to validate
  # @param total [Integer] total quantity for context
  # @raise [ArgumentError] if reserved quantity is invalid
  def validate_reserved_quantity(reserved, total)
    raise ArgumentError, 'Reserved quantity must be an integer' unless reserved.is_a?(Integer)
    raise ArgumentError, 'Reserved quantity cannot be negative' if reserved.negative?
    raise ArgumentError, 'Reserved quantity cannot exceed total quantity' if reserved > total
  end

  # Custom error class for insufficient quantity scenarios
  class InsufficientQuantityError < StandardError
    def initialize(message = 'Insufficient quantity for operation')
      super
    end
  end
end