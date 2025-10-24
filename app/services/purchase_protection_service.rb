# frozen_string_literal: true

# Service for managing purchase protection calculations and operations.
# Ensures accurate coverage calculations and compliance with protection policies.
class PurchaseProtectionService
  # Creates protection for an order with calculated coverage.
  # @param order [Order] The order to protect.
  # @param protection_type [Symbol] The type of protection.
  # @return [PurchaseProtection] The created protection.
  def self.create_for_order(order, protection_type = :buyer_protection)
    coverage_amount = calculate_coverage_amount(order, protection_type)

    PurchaseProtection.create!(
      order: order,
      user: order.user,
      protection_type: protection_type,
      coverage_amount_cents: coverage_amount,
      premium_cents: calculate_premium(coverage_amount, protection_type),
      starts_at: Time.current,
      expires_at: calculate_expiry(protection_type),
      status: :active
    )
  rescue StandardError => e
    Rails.logger.error("Failed to create protection for order #{order.id}: #{e.message}")
    raise
  end

  # Calculates coverage amount based on order and protection type.
  # @param order [Order] The order.
  # @param protection_type [Symbol] The protection type.
  # @return [Integer] Coverage amount in cents.
  def self.calculate_coverage_amount(order, protection_type)
    case protection_type.to_sym
    when :fraud_protection, :buyer_protection, :shipping_protection
      order.total_cents
    when :warranty_extension
      order.total_cents * 0.8 # 80% of order value
    when :price_protection
      order.total_cents * 0.2 # Up to 20% refund
    else
      0
    end
  end

  # Calculates premium based on coverage amount and protection type.
  # @param coverage_amount [Integer] Coverage amount in cents.
  # @param protection_type [Symbol] The protection type.
  # @return [Integer] Premium in cents.
  def self.calculate_premium(coverage_amount, protection_type)
    rate = case protection_type.to_sym
    when :fraud_protection
      0.01 # 1% of coverage
    when :buyer_protection
      0.02 # 2% of coverage
    when :shipping_protection
      0.015 # 1.5% of coverage
    when :warranty_extension
      0.05 # 5% of coverage
    when :price_protection
      0.01 # 1% of coverage
    else
      0.02 # Default 2%
    end

    (coverage_amount * rate).to_i
  end

  # Calculates expiry date based on protection type.
  # @param protection_type [Symbol] The protection type.
  # @return [Time] Expiry date.
  def self.calculate_expiry(protection_type)
    case protection_type.to_sym
    when :fraud_protection
      90.days.from_now
    when :buyer_protection
      60.days.from_now
    when :shipping_protection
      30.days.from_now
    when :warranty_extension
      2.years.from_now
    when :price_protection
      30.days.from_now
    else
      60.days.from_now # Default
    end
  end
end