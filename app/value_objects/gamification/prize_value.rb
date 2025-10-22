# frozen_string_literal: true

module Gamification
  # Immutable Prize Value Object
  # Represents the value of a prize, which can be numeric or descriptive
  class PrizeValue
    include Comparable

    attr_reader :amount, :type

    def initialize(amount, type = :numeric)
      @amount = validate_amount(amount)
      @type = validate_type(type)
      freeze
    end

    def self.numeric(amount)
      new(amount, :numeric)
    end

    def self.descriptive(description)
      new(description, :descriptive)
    end

    def numeric?
      type == :numeric
    end

    def descriptive?
      type == :descriptive
    end

    def add(other)
      raise ArgumentError, 'Cannot add descriptive values' unless numeric? && other.numeric?
      self.class.new(amount + other.amount, type)
    end

    def subtract(other)
      raise ArgumentError, 'Cannot subtract descriptive values' unless numeric? && other.numeric?
      self.class.new(amount - other.amount, type)
    end

    def multiply(factor)
      raise ArgumentError, 'Cannot multiply descriptive values' unless numeric?
      self.class.new(amount * factor, type)
    end

    def <=>(other)
      return nil unless other.is_a?(PrizeValue) && type == other.type
      amount <=> other.amount
    end

    def ==(other)
      other.is_a?(PrizeValue) && amount == other.amount && type == other.type
    end

    def hash
      [amount, type].hash
    end

    def to_s
      if numeric?
        amount.to_s
      else
        amount
      end
    end

    def inspect
      "#<#{self.class.name} #{to_s} (#{type})>"
    end

    private

    def validate_amount(amount)
      if type == :numeric
        Float(amount)
      else
        amount.to_s
      end
    end

    def validate_type(type)
      raise ArgumentError, 'Type must be :numeric or :descriptive' unless [:numeric, :descriptive].include?(type)
      type
    end
  end
end