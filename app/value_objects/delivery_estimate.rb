# Value Object for Delivery Estimate
class DeliveryEstimate
  attr_reader :min_days, :max_days

  def initialize(min_days, max_days)
    @min_days = min_days
    @max_days = max_days
    validate!
  end

  def to_s
    if min_days == max_days
      "#{min_days} business days"
    else
      "#{min_days}-#{max_days} business days"
    end
  end

  def ==(other)
    other.is_a?(DeliveryEstimate) && min_days == other.min_days && max_days == other.max_days
  end

  alias eql? ==

  def hash
    [min_days, max_days].hash
  end

  private

  def validate!
    raise ArgumentError, "min_days must be positive" unless min_days&.positive?
    raise ArgumentError, "max_days must be >= min_days" unless max_days.nil? || max_days >= min_days
  end
end