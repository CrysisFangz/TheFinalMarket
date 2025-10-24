# frozen_string_literal: true

# PurchaseProtection model refactored for resilience and compliance.
# Protection logic extracted into dedicated services for accuracy and auditability.
class PurchaseProtection < ApplicationRecord
  belongs_to :order
  belongs_to :user

  has_many :protection_claims, dependent: :destroy

  # Enhanced validations with custom messages
  validates :protection_type, presence: true, inclusion: { in: protection_types.keys }
  validates :coverage_amount_cents, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100000000 }
  validates :premium_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :starts_at, :expires_at, presence: true

  # Enhanced scopes with performance optimization
  scope :active, -> { where(status: :active) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :expiring_soon, -> { where('expires_at < ? AND expires_at > ?', 7.days.from_now, Time.current) }
  scope :with_claims, -> { includes(:protection_claims) }
  scope :by_type, ->(type) { where(protection_type: type) }

  # Event-driven: Publish events on status changes
  after_create :publish_protection_created_event
  after_update :publish_status_change_event, if: :saved_change_to_status?

  # Protection types
  enum protection_type: {
    fraud_protection: 0,      # Protection against fraudulent transactions
    buyer_protection: 1,      # Item not received or not as described
    shipping_protection: 2,   # Lost or damaged in shipping
    warranty_extension: 3,    # Extended warranty coverage
    price_protection: 4       # Price drop protection
  }

  # Protection status
  enum status: {
    active: 0,
    claimed: 1,
    expired: 2,
    cancelled: 3
  }

  # Create protection for order using service
  def self.create_for_order(order, protection_type = :buyer_protection)
    PurchaseProtectionService.create_for_order(order, protection_type)
  end

  # File a claim using service
  def file_claim(reason, description, evidence = {})
    ProtectionClaimFilingService.file_claim(self, reason, description, evidence)
  end

  # Check if can file claim
  def can_file_claim?
    active? && !expired? && protection_claims.pending.empty?
  end

  # Check if expired
  def expired?
    expires_at && expires_at < Time.current
  end

  # Get coverage details
  def coverage_details
    {
      type: protection_type,
      coverage_amount: coverage_amount_cents / 100.0,
      premium: premium_cents / 100.0,
      starts_at: starts_at,
      expires_at: expires_at,
      status: status,
      terms: coverage_terms
    }
  end
  
  # Get coverage terms
  def coverage_terms
    case protection_type.to_sym
    when :fraud_protection
      [
        'Full refund for unauthorized transactions',
        'Zero liability for fraudulent charges',
        'Identity theft assistance',
        '24/7 fraud monitoring'
      ]
    when :buyer_protection
      [
        'Full refund if item not received',
        'Full refund if item not as described',
        'Free return shipping',
        'Coverage up to order amount'
      ]
    when :shipping_protection
      [
        'Coverage for lost packages',
        'Coverage for damaged items',
        'Replacement or refund',
        'No deductible'
      ]
    when :warranty_extension
      [
        'Extended warranty coverage',
        'Covers manufacturer defects',
        'Free repairs or replacement',
        'Transferable coverage'
      ]
    when :price_protection
      [
        'Refund if price drops within 30 days',
        'Automatic price monitoring',
        'Up to 20% refund',
        'No claim limit'
      ]
    end
  end

  private

  def publish_protection_created_event
    Rails.logger.info("Purchase protection created: ID=#{id}, Type=#{protection_type}, Order=#{order_id}")
    # In a full event system: EventPublisher.publish('purchase_protection_created', self.attributes)
  end

  def publish_status_change_event
    Rails.logger.info("Purchase protection status changed: ID=#{id}, Status=#{status}")
    # In a full event system: EventPublisher.publish('purchase_protection_status_changed', self.attributes)
  end
end

