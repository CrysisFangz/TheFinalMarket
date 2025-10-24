# frozen_string_literal: true

# Enterprise Payment Account Service
# Core business logic for payment account operations with CQRS and Event Sourcing
class PaymentAccountService
  include ServiceResultHelper
  include CircuitBreakerHelper

  def initialize(payment_account)
    @payment_account = payment_account
  end

  # Process payment account activation with full audit trail
  def activate_account(activation_params = {})
    CircuitBreaker.execute_with_fallback(:payment_account_activation) do
      command = PaymentAccountCommands::ActivateAccountCommand.new(
        payment_account_id: @payment_account.id,
        activation_params: activation_params,
        request_id: SecureRandom.uuid
      )

      result = command.execute
      return failure_result("Account activation failed: #{result.error}") unless result.success?

      success_result(result.data, 'Payment account activated successfully')
    end
  rescue => e
    failure_result("Payment account activation error: #{e.message}")
  end

  # Process payment account suspension with compliance validation
  def suspend_account(suspension_reason, admin_user_id = nil)
    CircuitBreaker.execute_with_fallback(:payment_account_suspension) do
      command = PaymentAccountCommands::SuspendAccountCommand.new(
        payment_account_id: @payment_account.id,
        suspension_reason: suspension_reason,
        admin_user_id: admin_user_id,
        request_id: SecureRandom.uuid
      )

      result = command.execute
      return failure_result("Account suspension failed: #{result.error}") unless result.success?

      success_result(result.data, 'Payment account suspended successfully')
    end
  rescue => e
    failure_result("Payment account suspension error: #{e.message}")
  end

  # Update payment methods with validation and fraud detection
  def update_payment_methods(payment_methods_data)
    CircuitBreaker.execute_with_fallback(:payment_method_update) do
      command = PaymentAccountCommands::UpdatePaymentMethodsCommand.new(
        payment_account_id: @payment_account.id,
        payment_methods_data: payment_methods_data,
        request_id: SecureRandom.uuid
      )

      result = command.execute
      return failure_result("Payment methods update failed: #{result.error}") unless result.success?

      success_result(result.data, 'Payment methods updated successfully')
    end
  rescue => e
    failure_result("Payment methods update error: #{e.message}")
  end

  # Calculate account balance with caching and precision
  def calculate_balance(force_refresh: false)
    Rails.cache.fetch("payment_account_balance_#{@payment_account.id}", expires_in: 5.minutes, force: force_refresh) do
      PaymentBalanceCalculator.new.calculate_account_balance(@payment_account)
    end
  end

  # Assess account risk level using ML fraud detection
  def assess_risk_level(context = {})
    PaymentRiskAssessor.new.assess_account_risk(@payment_account, context)
  end

  # Validate account compliance status
  def validate_compliance(context = {})
    PaymentComplianceValidator.new.validate_account(@payment_account, context)
  end

  private

  attr_reader :payment_account
end