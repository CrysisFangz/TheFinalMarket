# frozen_string_literal: true

# Payment Account Validations
# Enterprise-grade validation with zero-trust architecture
module PaymentAccountValidations
  extend ActiveSupport::Concern

  included do
    # Core validations
    validates :user_id, presence: true, uniqueness: true
    validates :status, presence: true, inclusion: { in: %w[pending active suspended restricted terminated] }
    validates :account_type, presence: true, inclusion: { in: %w[standard premium enterprise] }
    validates :risk_level, presence: true, inclusion: { in: %w[low medium high critical extreme] }
    validates :compliance_status, presence: true, inclusion: { in: %w[unverified pending verified failed expired] }
    validates :kyc_status, presence: true, inclusion: { in: %w[unverified basic verified enhanced] }
    validates :verification_level, presence: true, inclusion: { in: %w[basic premium enterprise] }

    # Financial validations
    validates :available_balance_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :reserved_balance_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :pending_balance_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :daily_transaction_limit_cents, numericality: { greater_than: 0 }, allow_nil: true
    validates :monthly_transaction_limit_cents, numericality: { greater_than: 0 }, allow_nil: true

    # Security validations
    validates :fraud_detection_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
    validates :compliance_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
    validates :payment_velocity_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

    # Format validations
    validates :distributed_payment_id, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i }, allow_nil: true
    validates :blockchain_verification_hash, format: { with: /\A[0-9a-f]{64}\z/i }, allow_nil: true

    # Conditional validations
    validates :square_account_id, presence: true, if: :square_integration_enabled?
    validates :business_email, presence: true, format: { with: Devise.email_regexp }, if: :business_account?
    validates :merchant_name, presence: true, if: :business_account?

    # Payment methods validation
    validate :validate_payment_methods_structure
    validate :validate_payment_methods_security

    # Business rule validations
    validate :validate_balance_consistency
    validate :validate_risk_compliance_alignment
    validate :validate_transaction_limits

    # Cross-field validations
    validate :validate_account_type_requirements
    validate :validate_verification_level_requirements
  end

  # Payment methods structure validation
  def validate_payment_methods_structure
    return if payment_methods.blank?

    unless payment_methods.is_a?(Array)
      errors.add(:payment_methods, 'must be an array')
      return
    end

    payment_methods.each_with_index do |method, index|
      validate_single_payment_method(method, index)
    end
  end

  def validate_single_payment_method(method, index)
    return unless method.is_a?(Hash)

    # Required fields for each payment method
    required_fields = %i[type token last_four]
    missing_fields = required_fields.select { |field| method[field].blank? }

    if missing_fields.any?
      errors.add(:payment_methods, "method #{index + 1} missing: #{missing_fields.join(', ')}")
    end

    # Type-specific validations
    case method[:type]
    when 'credit_card', 'debit_card'
      validate_card_method(method, index)
    when 'bank_account'
      validate_bank_method(method, index)
    when 'digital_wallet'
      validate_wallet_method(method, index)
    when 'crypto'
      validate_crypto_method(method, index)
    else
      errors.add(:payment_methods, "method #{index + 1} has invalid type: #{method[:type]}")
    end
  end

  def validate_card_method(method, index)
    # Validate card-specific fields
    if method[:expiry_month] && method[:expiry_year]
      begin
        expiry_date = Date.new(method[:expiry_year].to_i, method[:expiry_month].to_i, 1)
        if expiry_date < Date.current.end_of_month
          errors.add(:payment_methods, "method #{index + 1} has expired card")
        end
      rescue ArgumentError
        errors.add(:payment_methods, "method #{index + 1} has invalid expiry date")
      end
    end

    # Validate CVV if present
    if method[:cvv] && method[:cvv] !~ /^\d{3,4}$/
      errors.add(:payment_methods, "method #{index + 1} has invalid CVV format")
    end
  end

  def validate_bank_method(method, index)
    # Validate bank-specific fields
    if method[:routing_number] && method[:routing_number] !~ /^\d{9}$/
      errors.add(:payment_methods, "method #{index + 1} has invalid routing number")
    end

    if method[:account_number] && method[:account_number].length < 4
      errors.add(:payment_methods, "method #{index + 1} has invalid account number")
    end
  end

  def validate_wallet_method(method, index)
    # Validate digital wallet fields
    valid_wallets = %w[apple_pay google_pay samsung_pay paypal]
    unless valid_wallets.include?(method[:wallet_type])
      errors.add(:payment_methods, "method #{index + 1} has invalid wallet type")
    end
  end

  def validate_crypto_method(method, index)
    # Validate cryptocurrency fields
    valid_cryptos = %w[bitcoin ethereum xrp litecoin]
    unless valid_cryptos.include?(method[:cryptocurrency])
      errors.add(:payment_methods, "method #{index + 1} has invalid cryptocurrency")
    end

    if method[:wallet_address] && method[:wallet_address].length < 20
      errors.add(:payment_methods, "method #{index + 1} has invalid wallet address")
    end
  end

  # Payment methods security validation
  def validate_payment_methods_security
    return if payment_methods.blank?

    # Check for suspicious patterns
    detect_suspicious_payment_patterns
    detect_duplicate_payment_methods
    detect_high_risk_payment_methods
  end

  def detect_suspicious_payment_patterns
    # Check for sequential card numbers
    card_methods = payment_methods.select { |m| %w[credit_card debit_card].include?(m[:type]) }
    return if card_methods.size < 2

    last_fours = card_methods.map { |m| m[:last_four].to_i }.sort
    if last_fours.each_cons(2).any? { |a, b| (b - a).abs == 1 }
      errors.add(:payment_methods, 'suspicious sequential card pattern detected')
    end
  end

  def detect_duplicate_payment_methods
    seen_tokens = Set.new

    payment_methods.each_with_index do |method, index|
      token = method[:token]
      if seen_tokens.include?(token)
        errors.add(:payment_methods, "method #{index + 1} is a duplicate")
      end
      seen_tokens.add(token)
    end
  end

  def detect_high_risk_payment_methods
    payment_methods.each_with_index do |method, index|
      risk_score = calculate_payment_method_risk_score(method)
      if risk_score > 0.8
        errors.add(:payment_methods, "method #{index + 1} has high risk score: #{risk_score}")
      end
    end
  end

  # Balance consistency validation
  def validate_balance_consistency
    return if available_balance_cents.blank? || reserved_balance_cents.blank? || pending_balance_cents.blank?

    total_balance = available_balance_cents + reserved_balance_cents + pending_balance_cents

    # Validate against transaction totals (simplified)
    transaction_total = payment_transactions.where(status: :completed).sum(:amount_cents)
    if total_balance.negative? || (total_balance - transaction_total).abs > 100 # Allow $1 variance
      errors.add(:base, 'balance inconsistency detected')
    end
  end

  # Risk-compliance alignment validation
  def validate_risk_compliance_alignment
    return if risk_level.blank? || compliance_status.blank?

    # High risk accounts should have verified compliance
    if high_risk? && !compliant?
      errors.add(:compliance_status, 'must be verified for high-risk accounts')
    end

    # Critical/extreme risk accounts should be suspended or terminated
    if %w[extreme].include?(risk_level) && active?
      errors.add(:status, 'must not be active for extreme risk accounts')
    end
  end

  # Transaction limits validation
  def validate_transaction_limits
    return if daily_transaction_limit_cents.blank? || monthly_transaction_limit_cents.blank?

    # Daily limit should be less than monthly limit
    if daily_transaction_limit_cents >= monthly_transaction_limit_cents
      errors.add(:daily_transaction_limit_cents, 'must be less than monthly limit')
    end

    # Limits should be reasonable (not too high or too low)
    min_daily = 10000    # $100
    max_daily = 100000000 # $1,000,000
    min_monthly = 100000  # $1,000
    max_monthly = 1000000000 # $10,000,000

    if daily_transaction_limit_cents < min_daily || daily_transaction_limit_cents > max_daily
      errors.add(:daily_transaction_limit_cents, "must be between #{min_daily} and #{max_daily} cents")
    end

    if monthly_transaction_limit_cents < min_monthly || monthly_transaction_limit_cents > max_monthly
      errors.add(:monthly_transaction_limit_cents, "must be between #{min_monthly} and #{max_monthly} cents")
    end
  end

  # Account type requirements validation
  def validate_account_type_requirements
    case account_type
    when 'premium'
      validate_premium_requirements
    when 'enterprise'
      validate_enterprise_requirements
    end
  end

  def validate_premium_requirements
    if verification_level != 'premium'
      errors.add(:verification_level, 'must be premium for premium accounts')
    end

    if compliance_status != 'verified'
      errors.add(:compliance_status, 'must be verified for premium accounts')
    end
  end

  def validate_enterprise_requirements
    if verification_level != 'enterprise'
      errors.add(:verification_level, 'must be enterprise for enterprise accounts')
    end

    if kyc_status != 'enhanced'
      errors.add(:kyc_status, 'must be enhanced for enterprise accounts')
    end

    if business_email.blank?
      errors.add(:business_email, 'is required for enterprise accounts')
    end

    if merchant_name.blank?
      errors.add(:merchant_name, 'is required for enterprise accounts')
    end
  end

  # Verification level requirements validation
  def validate_verification_level_requirements
    case verification_level
    when 'premium'
      if compliance_status != 'verified'
        errors.add(:compliance_status, 'must be verified for premium verification')
      end
    when 'enterprise'
      if kyc_status != 'enhanced'
        errors.add(:kyc_status, 'must be enhanced for enterprise verification')
      end
    end
  end

  # Helper methods for validations
  def square_integration_enabled?
    account_type == 'enterprise' || payment_methods&.any? { |pm| pm[:processor] == 'square' }
  end

  def business_account?
    account_type == 'enterprise'
  end

  def calculate_payment_method_risk_score(method)
    # Simplified risk calculation
    risk_factors = []

    # Token format risk
    risk_factors << 0.3 if method[:token] =~ /^test_|fake|dummy/i

    # Type-based risk
    type_risks = {
      'credit_card' => 0.1,
      'debit_card' => 0.05,
      'bank_account' => 0.2,
      'digital_wallet' => 0.15,
      'crypto' => 0.4
    }
    risk_factors << (type_risks[method[:type]] || 0.3)

    # Geographic risk (simplified)
    risk_factors << 0.2 if method[:country] && method[:country] != 'US'

    risk_factors.max || 0.0
  end
end