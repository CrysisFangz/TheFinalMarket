class PricingRule < ApplicationRecord
  belongs_to :product
  belongs_to :user
  
  has_many :price_changes, depent: :destroy
  has_many :pricing_rule_conditions, depent: :destroy
  
  # Rule types
  enum rule_type: {
    time_based: 0,        # Flash sales, happy hours
    inventory_based: 1,   # Clearance pricing
    demand_based: 2,      # Surge pricing
    competitor_based: 3,  # Price matching
    seasonal: 4,          # Holiday pricing
    bundle: 5,            # Bundle discounts
    volume: 6,            # Bulk discounts
    dynamic_ai: 7         # AI-optimized pricing
  }
  
  # Status
  enum status: {
    draft: 0,
    active: 1,
    paused: 2,
    expired: 3,
    archived: 4
  }
  
  # Priority levels (higher number = higher priority)
  enum priority: {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }
  
  validates :name, presence: true
  validates :rule_type, presence: true
  validates :min_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :priority, presence: true
  
  validate :validate_price_bounds
  validate :validate_date_range
  
  scope :active, -> { where(status: :active) }
  scope :for_product, ->(product) { where(product: product) }
  scope :by_priority, -> { order(priority: :desc, created_at: :desc) }
  scope :current, -> { where('start_date <= ? AND (_date IS NULL OR _date >= ?)', Date.current, Date.current) }
  
  # Calculate price based on this rule
  def calculate_price(base_price, context = {})
    calculation_service.calculate_price(base_price, context)
  

  # Check if rule is applicable in current context
  def applicable?(context = {})
    calculation_service.applicable?(context)
  

  # Apply the rule and create price change record
  def apply!(context = {})
    application_service.apply!(context)
  

  # Get configuration data
  def config
    configuration || {}
  

  # Service delegations
  def calculation_service
    @calculation_service ||= PricingRuleCalculationService.new(self)
  

  def application_service
    @application_service ||= PricingRuleApplicationService.new(self)
  

  private
  
  
  
  
  
  
  
  
    
    
                                      
                                      
                                      
  
  
  
  
  
  
  
  
  
  
  
  
  def validate_price_bounds
    if min_price_cents && max_price_cents && min_price_cents > max_price_cents
      errors.add(:min_price_cents, "cannot be greater than max price")
    
  
  
  def validate_date_range
    if start_date && _date && start_date > _date
      errors.add(:start_date, "cannot be after  date")
    
  


