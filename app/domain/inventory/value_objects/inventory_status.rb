# frozen_string_literal: true

# Immutable value object representing inventory status
# Encapsulates business rules for determining stock status and alerts
class InventoryStatus
  attr_reader :level, :alerts, :last_updated, :metadata

  # Stock status levels
  IN_STOCK = :in_stock
  LOW_STOCK = :low_stock
  OUT_OF_STOCK = :out_of_stock
  OVERSTOCKED = :overstocked

  # Alert severity levels
  INFO = :info
  WARNING = :warning
  CRITICAL = :critical
  EMERGENCY = :emergency

  # Thresholds for status determination
  LOW_STOCK_THRESHOLD = 10
  CRITICAL_STOCK_THRESHOLD = 0
  OVERSTOCK_MULTIPLIER = 5.0

  # Create a new inventory status
  # @param quantity [Quantity] current inventory quantity
  # @param low_stock_threshold [Integer] custom threshold for low stock alerts
  # @param overstock_threshold [Integer] custom threshold for overstock warnings
  def initialize(quantity, low_stock_threshold: nil, overstock_threshold: nil)
    @quantity = quantity
    @low_stock_threshold = low_stock_threshold || LOW_STOCK_THRESHOLD
    @overstock_threshold = overstock_threshold || calculate_overstock_threshold
    @last_updated = Time.current
    @metadata = {}

    determine_level
    generate_alerts
    freeze # Make immutable
  end

  # Current stock level
  # @return [Symbol] current status level
  def level
    @level ||= determine_level
  end

  # Array of active alerts
  # @return [Array<Alert>] active alerts for current status
  def alerts
    @alerts ||= generate_alerts
  end

  # Check if inventory is in stock
  # @return [Boolean] true if inventory has available quantity
  def in_stock?
    level == IN_STOCK
  end

  # Check if inventory is low on stock
  # @return [Boolean] true if inventory is below low stock threshold
  def low_stock?
    level == LOW_STOCK
  end

  # Check if inventory is out of stock
  # @return [Boolean] true if no inventory is available
  def out_of_stock?
    level == OUT_OF_STOCK
  end

  # Check if inventory is overstocked
  # @return [Boolean] true if inventory exceeds overstock threshold
  def overstocked?
    level == OVERSTOCKED
  end

  # Check if any critical alerts are active
  # @return [Boolean] true if critical alerts exist
  def has_critical_alerts?
    alerts.any? { |alert| alert.severity == CRITICAL || alert.severity == EMERGENCY }
  end

  # Get the most severe active alert
  # @return [Alert, nil] most severe alert or nil if no alerts
  def highest_priority_alert
    alerts.max_by(&:priority_score)
  end

  # Calculate days until stockout based on current allocation rate
  # @param allocation_rate [Float] average daily allocation rate
  # @return [Integer, nil] days until stockout or nil if not applicable
  def days_until_stockout(allocation_rate = nil)
    return nil if out_of_stock? || @quantity.available.zero?

    if allocation_rate&.positive?
      (@quantity.available / allocation_rate).to_i
    else
      # Estimate based on historical trends or return nil
      estimate_allocation_rate
    end
  end

  # Calculate stock coverage ratio (available / threshold)
  # @return [Float] coverage ratio as percentage
  def coverage_ratio
    return 0.0 if @low_stock_threshold.zero?

    [@quantity.available.to_f / @low_stock_threshold, 2.0].min * 100
  end

  # Generate recommendation based on current status
  # @return [String] recommendation message
  def recommendation
    case level
    when OUT_OF_STOCK
      'URGENT: Restock immediately to resume operations'
    when LOW_STOCK
      'WARNING: Schedule restock within 48 hours'
    when IN_STOCK
      'OPTIMAL: Inventory levels are healthy'
    when OVERSTOCKED
      'INFO: Consider promotional activities to reduce excess stock'
    else
      'UNKNOWN: Review inventory status'
    end
  end

  # Equality comparison
  # @param other [InventoryStatus] status to compare with
  # @return [Boolean] true if statuses are equal
  def ==(other)
    other.is_a?(InventoryStatus) &&
    @level == other.level &&
    @alerts.length == other.alerts.length &&
    @quantity == other.instance_variable_get(:@quantity)
  end

  alias eql? ==

  # Hash for use in hash-based collections
  # @return [Integer] hash code
  def hash
    [@level, @quantity, @alerts.length].hash
  end

  # Convert to hash for serialization
  # @return [Hash] serializable hash
  def to_h
    {
      level: level,
      alerts: alerts.map(&:to_h),
      coverage_ratio: coverage_ratio,
      recommendation: recommendation,
      last_updated: @last_updated,
      metadata: @metadata
    }
  end

  private

  # Determine the current stock level based on quantity
  # @return [Symbol] determined stock level
  def determine_level
    if @quantity.out_of_stock?
      OUT_OF_STOCK
    elsif @quantity.available <= CRITICAL_STOCK_THRESHOLD
      OUT_OF_STOCK
    elsif @quantity.available <= @low_stock_threshold
      LOW_STOCK
    elsif @quantity.available > @overstock_threshold
      OVERSTOCKED
    else
      IN_STOCK
    end
  end

  # Generate alerts for current status
  # @return [Array<Alert>] array of active alerts
  def generate_alerts
    alerts = []

    case level
    when OUT_OF_STOCK
      alerts << Alert.new(
        :stockout_critical,
        'CRITICAL: Inventory completely depleted',
        CRITICAL,
        'Immediate restock required to continue operations'
      )
    when LOW_STOCK
      alerts << Alert.new(
        :low_stock_warning,
        "WARNING: Only #{@quantity.available} units remaining",
        WARNING,
        "Schedule restock within 48 hours. Coverage ratio: #{coverage_ratio.round(1)}%"
      )
    when OVERSTOCKED
      alerts << Alert.new(
        :overstock_info,
        "INFO: Inventory exceeds optimal levels (#{@quantity.available} units)",
        INFO,
        'Consider promotional activities or inventory optimization'
      )
    end

    # Add high reservation alert if applicable
    if @quantity.utilization_rate > 0.8
      alerts << Alert.new(
        :high_reservation,
        "INFO: High reservation rate (#{(@quantity.utilization_rate * 100).round(1)}%)",
        INFO,
        'Monitor for potential stock conflicts'
      )
    end

    alerts
  end

  # Calculate overstock threshold based on business rules
  # @return [Integer] calculated overstock threshold
  def calculate_overstock_threshold
    (@low_stock_threshold * OVERSTOCK_MULTIPLIER).to_i
  end

  # Estimate allocation rate from historical data
  # @return [Float, nil] estimated daily allocation rate
  def estimate_allocation_rate
    # This would typically query historical allocation data
    # For now, return a conservative estimate
    [@quantity.value * 0.1, 1.0].max # Assume 10% daily allocation or minimum 1
  end

  # Alert value object for status notifications
  class Alert
    attr_reader :type, :message, :severity, :description, :timestamp

    # Priority scores for alert sorting
    PRIORITY_SCORES = {
      EMERGENCY => 100,
      CRITICAL => 80,
      WARNING => 50,
      INFO => 20
    }.freeze

    # Create a new alert
    # @param type [Symbol] alert type identifier
    # @param message [String] alert message
    # @param severity [Symbol] alert severity level
    # @param description [String] detailed description
    def initialize(type, message, severity, description)
      @type = type
      @message = message
      @severity = severity
      @description = description
      @timestamp = Time.current
      freeze
    end

    # Calculate priority score for alert sorting
    # @return [Integer] priority score
    def priority_score
      PRIORITY_SCORES[@severity] || 0
    end

    # Convert to hash for serialization
    # @return [Hash] serializable hash
    def to_h
      {
        type: @type,
        message: @message,
        severity: @severity,
        description: @description,
        timestamp: @timestamp,
        priority_score: priority_score
      }
    end
  end
end