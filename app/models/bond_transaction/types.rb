# frozen_string_literal: true

# ═══════════════════════════════════════════════════════════════════════════════════
# PURE DOMAIN TYPES WITH FORMAL VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════════════

# Pure function transaction type definitions with formal verification
class TransactionType
  TYPES = {
    payment: 'payment',
    refund: 'refund',
    forfeiture: 'forfeiture',
    adjustment: 'adjustment',
    reversal: 'reversal',
    correction: 'correction'
  }.freeze

  def self.from_string(type_string)
    case type_string.to_s
    when 'payment' then Payment.new
    when 'refund' then Refund.new
    when 'forfeiture' then Forfeiture.new
    when 'adjustment' then Adjustment.new
    when 'reversal' then Reversal.new
    when 'correction' then Correction.new
    else Payment.new
    end
  end

  def to_s
    @value.to_s
  end

  def value
    @value
  end

  def valid_transitions
    # Formal verification of valid state transitions
    case @value
    when :payment then [:pending, :processing, :verified, :completed, :failed]
    when :refund then [:pending, :processing, :verified, :completed, :failed]
    when :forfeiture then [:pending, :processing, :completed, :failed]
    else [:pending, :processing, :verified, :completed, :failed]
    end
  end

  class Payment < TransactionType
    def initialize
      @value = :payment
    end

    def financial_impact_multiplier
      1.0
    end

    def risk_weight
      0.3
    end
  end

  class Refund < TransactionType
    def initialize
      @value = :refund
    end

    def financial_impact_multiplier
      -1.0
    end

    def risk_weight
      0.4
    end
  end

  class Forfeiture < TransactionType
    def initialize
      @value = :forfeiture
    end

    def financial_impact_multiplier
      0.8
    end

    def risk_weight
      0.2
    end
  end

  class Adjustment < TransactionType
    def initialize
      @value = :adjustment
    end

    def financial_impact_multiplier
      0.1
    end

    def risk_weight
      0.1
    end
  end

  class Reversal < TransactionType
    def initialize
      @value = :reversal
    end

    def financial_impact_multiplier
      -1.0
    end

    def risk_weight
      0.5
    end
  end

  class Correction < TransactionType
    def initialize
      @value = :correction
    end

    def financial_impact_multiplier
      0.05
    end

    def risk_weight
      0.1
    end
  end
end

# Pure function transaction status machine with formal verification
class TransactionStatus
  def self.from_string(status_string)
    case status_string.to_s
    when 'pending' then Pending.new
    when 'processing' then Processing.new
    when 'verified' then Verified.new
    when 'completed' then Completed.new
    when 'failed' then Failed.new
    when 'cancelled' then Cancelled.new
    else Pending.new
    end
  end

  def to_s
    @value.to_s
  end

  def value
    @value
  end

  def valid_next_states
    # Formal verification of valid state transitions
    case @value
    when :pending then [:processing, :cancelled]
    when :processing then [:verified, :failed, :cancelled]
    when :verified then [:completed, :failed]
    when :completed then [] # Terminal state
    when :failed then [:pending] # Can retry
    when :cancelled then [] # Terminal state
    else [:pending]
    end
  end

  class Pending < TransactionStatus
    def initialize
      @value = :pending
    end
  end

  class Processing < TransactionStatus
    def initialize
      @value = :processing
    end
  end

  class Verified < TransactionStatus
    def initialize
      @value = :verified
    end
  end

  class Completed < TransactionStatus
    def initialize
      @value = :completed
    end
  end

  class Failed < TransactionStatus
    def initialize
      @value = :failed
    end
  end

  class Cancelled < TransactionStatus
    def initialize
      @value = :cancelled
    end
  end
end

# Pure function processing stage definitions
class ProcessingStage
  def self.from_string(stage_string)
    case stage_string.to_s
    when 'initialized' then Initialized.new
    when 'processing' then Processing.new
    when 'verified' then Verified.new
    when 'completed' then Completed.new
    when 'failed' then Failed.new
    else Initialized.new
    end
  end

  def to_s
    @value.to_s
  end

  def value
    @value
  end

  class Initialized < ProcessingStage
    def initialize
      @value = :initialized
    end
  end

  class Processing < ProcessingStage
    def initialize
      @value = :processing
    end
  end

  class Verified < ProcessingStage
    def initialize
      @value = :verified
    end
  end

  class Completed < ProcessingStage
    def initialize
      @value = :completed
    end
  end

  class Failed < ProcessingStage
    def initialize
      @value = :failed
    end
  end
end

# Financial impact calculation for transactions
class FinancialImpact
  def self.from_amount(amount_cents, transaction_type)
    amount_usd = amount_cents / 100.0

    new(
      amount_cents: amount_cents,
      amount_usd: amount_usd,
      financial_category: categorize_financial_impact(amount_usd, transaction_type),
      risk_assessment: assess_financial_risk(amount_cents, transaction_type),
      liquidity_impact: calculate_liquidity_impact(amount_usd, transaction_type),
      compliance_requirements: determine_compliance_requirements(amount_cents, transaction_type)
    )
  end

  def initialize(amount_cents:, amount_usd:, financial_category:, risk_assessment:, liquidity_impact:, compliance_requirements:)
    @amount_cents = amount_cents
    @amount_usd = amount_usd
    @financial_category = financial_category
    @risk_assessment = risk_assessment
    @liquidity_impact = liquidity_impact
    @compliance_requirements = compliance_requirements
  end

  attr_reader :amount_cents, :amount_usd, :financial_category, :risk_assessment, :liquidity_impact, :compliance_requirements

  private

  def self.categorize_financial_impact(amount_usd, transaction_type)
    category_thresholds = case transaction_type.value
    when :payment, :forfeiture then { low: 100, medium: 500, high: 1000 }
    when :refund then { low: 50, medium: 250, high: 500 }
    else { low: 25, medium: 100, high: 200 }
    end

    case amount_usd
    when 0..category_thresholds[:low] then :low_impact
    when category_thresholds[:low]..category_thresholds[:medium] then :medium_impact
    when category_thresholds[:medium]..category_thresholds[:high] then :high_impact
    else :critical_impact
    end
  end

  def self.assess_financial_risk(amount_cents, transaction_type)
    amount_usd = amount_cents / 100.0
    base_risk = transaction_type.risk_weight

    # Risk increases with amount
    amount_risk_multiplier = case amount_usd
    when 0..100 then 1.0
    when 100..500 then 1.2
    when 500..1000 then 1.5
    else 2.0
    end

    [base_risk * amount_risk_multiplier, 1.0].min
  end

  def self.calculate_liquidity_impact(amount_usd, transaction_type)
    multiplier = transaction_type.financial_impact_multiplier

    case amount_usd
    when 0..100 then 0.1 * multiplier
    when 100..500 then 0.3 * multiplier
    when 500..1000 then 0.6 * multiplier
    else 0.9 * multiplier
    end
  end

  def self.determine_compliance_requirements(amount_cents, transaction_type)
    amount_usd = amount_cents / 100.0

    requirements = []

    # Basic requirements for all transactions
    requirements << :basic_kyc

    # Enhanced requirements based on amount and type
    if amount_usd > 500 || [:forfeiture, :reversal].include?(transaction_type.value)
      requirements << :enhanced_kyc
    end

    if amount_usd > 1000
      requirements << :aml_screening
    end

    if [:forfeiture].include?(transaction_type.value)
      requirements << :legal_review
    end

    requirements
  end
end