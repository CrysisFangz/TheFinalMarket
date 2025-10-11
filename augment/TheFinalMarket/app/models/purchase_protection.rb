class PurchaseProtection < ApplicationRecord
  belongs_to :order
  belongs_to :user
  
  has_many :protection_claims, dependent: :destroy
  
  validates :protection_type, presence: true
  validates :coverage_amount_cents, presence: true
  
  scope :active, -> { where(status: :active) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  
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
  
  # Create protection for order
  def self.create_for_order(order, protection_type = :buyer_protection)
    coverage_amount = calculate_coverage_amount(order, protection_type)
    
    create!(
      order: order,
      user: order.user,
      protection_type: protection_type,
      coverage_amount_cents: coverage_amount,
      premium_cents: calculate_premium(coverage_amount, protection_type),
      starts_at: Time.current,
      expires_at: calculate_expiry(protection_type),
      status: :active
    )
  end
  
  # File a claim
  def file_claim(reason, description, evidence = {})
    return false unless can_file_claim?
    
    claim = protection_claims.create!(
      reason: reason,
      description: description,
      evidence: evidence,
      claim_amount_cents: coverage_amount_cents,
      filed_at: Time.current,
      status: :pending
    )
    
    update!(status: :claimed)
    
    # Notify claims team
    ProtectionClaimMailer.new_claim(claim).deliver_later
    
    claim
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
  
  def self.calculate_coverage_amount(order, protection_type)
    case protection_type.to_sym
    when :fraud_protection, :buyer_protection, :shipping_protection
      order.total_cents
    when :warranty_extension
      order.total_cents * 0.8 # 80% of order value
    when :price_protection
      order.total_cents * 0.2 # Up to 20% refund
    end
  end
  
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
    end
    
    (coverage_amount * rate).to_i
  end
  
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
    end
  end
end

