# frozen_string_literal: true

# Value Object for representing monetary amounts in cents to avoid floating-point precision issues.
# Ensures immutability and provides methods for conversion and operations.
class Amount
  attr_reader :cents

  def initialize(cents)
    @cents = cents.to_i
    freeze
  end

  def to_dollars
    cents / 100.0
  end

  def to_s
    format('$%.2f', to_dollars)
  end

  def +(other)
    self.class.new(cents + other.cents)
  end

  def -(other)
    self.class.new(cents - other.cents)
  end

  def ==(other)
    other.is_a?(self.class) && cents == other.cents
  end

  def hash
    [self.class, cents].hash
  end

  def positive?
    cents > 0
  end

  def negative?
    cents < 0
  end

  def zero?
    cents.zero?
  end
end