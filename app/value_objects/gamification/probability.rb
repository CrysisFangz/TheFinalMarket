# frozen_string_literal: true

module Gamification
  # Immutable Probability Value Object
  # Represents a probability as a percentage (0.0 to 100.0)
  class Probability
    include Comparable

    MIN_PROBABILITY = 0.0
    MAX_PROBABILITY = 100.0

    attr_reader :value

    def initialize(value)
      @value = validate_probability(value)
      freeze
    end

    def self.zero
      new(0.0)
    end

    def self.full
      new(100.0)
    end

    def add(other)
      self.class.new(value + other.value)
    end

    def subtract(other)
      self.class.new(value - other.value)
    end

    def multiply(factor)
      self.class.new(value * factor)
    end

    def <=>(other)
      value <=> other.value
    end

    def ==(other)
      other.is_a?(Probability) && value == other.value
    end

    def hash
      value.hash
    end

    def to_f
      value
    end

    def to_s
      "#{value}%"
    end

    def inspect
      "#<#{self.class.name} #{to_s}>"
    end

    def valid?
      value.between?(MIN_PROBABILITY, MAX_PROBABILITY)
    end

    private

    def validate_probability(value)
      value = Float(value)
      raise ArgumentError, "Probability must be between #{MIN_PROBABILITY} and #{MAX_PROBABILITY}" unless value.between?(MIN_PROBABILITY, MAX_PROBABILITY)
      value
    end
  end
end