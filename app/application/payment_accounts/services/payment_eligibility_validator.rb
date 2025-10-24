# frozen_string_literal: true

# Enterprise Payment Eligibility Validator
# Comprehensive validation for payment eligibility with business rules
class PaymentEligibilityValidator
  include ServiceResultHelper

  # Validate payment eligibility for account and order
  def validate(payment_account, order)
    CircuitBreaker.execute_with_fallback(:payment_eligibility) do
      validations = [
        -> { validate_account_status(payment_account) },
        -> { validate_risk_level(payment_account) },
        -> { validate_compliance_status(payment_account) },
        -> { validate_balance_adequacy(payment_account, order) },
        -> { validate_payment_methods(payment_account) },
        -> { validate_business_rules(payment_account, order) }
      ]

      validation_results = validations.map(&:call)

      if validation_results.all?(&:success?)
        success_result(validation_results, 'Payment eligibility validated')
      else
        failure_result('Payment eligibility validation failed', validation_results)
      end
    end
  end

  private

  def validate_account_status(payment_account)
    unless payment_account.active?
      return failure_result("Account status is #{payment_account.status}")
    end

    success_result('Account status validation passed')
  end

  def validate_risk_level(payment_account)
    risk_level = payment_account.risk_level

    if %w[critical extreme].include?(risk_level)
      return failure_result("Risk level #{risk_level} prevents payments")
    end

    success_result('Risk level validation passed')
  end

  def validate_compliance_status(payment_account)
    unless payment_account.compliant?
      return failure_result('Account is not compliant')
    end

    success_result('Compliance status validation passed')
  end

  def validate_balance_adequacy(payment_account, order)
    required_amount = order.total_amount
    available_balance = payment_account.available_balance

    if available_balance < required_amount
      return failure_result("Insufficient balance: #{available_balance} < #{required_amount}")
    end

    success_result('Balance adequacy validation passed')
  end

  def validate_payment_methods(payment_account)
    payment_methods = payment_account.payment_methods

    if payment_methods.blank?
      return failure_result('No payment methods configured')
    end

    # Validate at least one active payment method
    active_methods = payment_methods.select { |pm| pm[:active] != false }
    if active_methods.blank?
      return failure_result('No active payment methods available')
    end

    success_result('Payment methods validation passed')
  end

  def validate_business_rules(payment_account, order)
    # Validate order-specific business rules
    if order.high_risk?
      unless payment_account.premium_verified?
        return failure_result('Premium verification required for high-risk orders')
      end
    end

    # Validate amount thresholds
    if order.total_amount > Money.new(100000) # $1000
      unless payment_account.enhanced_verification?
        return failure_result('Enhanced verification required for large amounts')
      end
    end

    success_result('Business rules validation passed')
  end
end