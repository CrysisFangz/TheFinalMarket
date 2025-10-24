# frozen_string_literal: true

# Value Object for representing wallet balances in cents, ensuring immutability and precision.
class Balance
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

  def +(amount)
    self.class.new(cents + amount.cents)
  end

  def -(amount)
    self.class.new(cents - amount.cents)
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

  def sufficient_for?(amount)
    cents >= amount.cents
  end
end