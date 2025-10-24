# frozen_string_literal: true

# Enterprise Payment Method Validator
# Comprehensive validation for payment methods with fraud detection
class PaymentMethodValidator
  include ServiceResultHelper

  # Validate payment methods for an account
  def validate_methods(payment_methods_data, payment_account)
    CircuitBreaker.execute_with_fallback(:payment_method_validation) do
      validation_results = []
      overall_success = true

      payment_methods_data.each_with_index do |method_data, index|
        method_result = validate_single_method(method_data, payment_account, index)
        validation_results << method_result

        overall_success &&= method_result[:success]
      end

      # Execute cross-method validation
      cross_method_result = validate_cross_method_rules(payment_methods_data, payment_account)
      validation_results << cross_method_result
      overall_success &&= cross_method_result[:success]

      if overall_success
        success_result(validation_results, 'All payment methods validated successfully')
      else
        failure_result('Payment method validation failed', validation_results)
      end
    end
  end

  private

  def validate_single_method(method_data, payment_account, index)
    validations = [
      -> { validate_method_structure(method_data, index) },
      -> { validate_payment_type(method_data, index) },
      -> { validate_card_details(method_data, index) },
      -> { validate_token_format(method_data, index) },
      -> { validate_duplicate_detection(method_data, payment_account, index) },
      -> { validate_fraud_indicators(method_data, payment_account, index) }
    ]

    errors = []
    validations.each do |validation|
      begin
        result = validation.call
        return result unless result[:success]
      rescue => e
        errors << e.message
      end
    end

    if errors.any?
      {
        success: false,
        method_index: index,
        errors: errors,
        method_data: method_data
      }
    else
      {
        success: true,
        method_index: index,
        method_data: method_data,
        validation_details: 'Method validation passed'
      }
    end
  end

  def validate_method_structure(method_data, index)
    required_fields = %i[type token last_four]
    missing_fields = required_fields.select { |field| method_data[field].blank? }

    if missing_fields.any?
      raise ValidationError, "Payment method #{index + 1} missing required fields: #{missing_fields.join(', ')}"
    end

    { success: true }
  end

  def validate_payment_type(method_data, index)
    valid_types = %w[credit_card debit_card bank_account digital_wallet crypto]
    payment_type = method_data[:type]

    unless valid_types.include?(payment_type)
      raise ValidationError, "Payment method #{index + 1} has invalid type: #{payment_type}"
    end

    { success: true }
  end

  def validate_card_details(method_data, index)
    return { success: true } unless method_data[:type] == 'credit_card' || method_data[:type] == 'debit_card'

    # Validate card number format (simplified)
    last_four = method_data[:last_four]
    unless last_four =~ /^\d{4}$/
      raise ValidationError, "Payment method #{index + 1} has invalid last four digits: #{last_four}"
    end

    # Validate expiration if provided
    if method_data[:expiry_month] && method_data[:expiry_year]
      begin
        expiry_date = Date.new(method_data[:expiry_year].to_i, method_data[:expiry_month].to_i, 1)
        if expiry_date < Date.current.end_of_month
          raise ValidationError, "Payment method #{index + 1} has expired card"
        end
      rescue ArgumentError
        raise ValidationError, "Payment method #{index + 1} has invalid expiry date"
      end
    end

    { success: true }
  end

  def validate_token_format(method_data, index)
    token = method_data[:token]

    # Basic token format validation
    if token.blank? || token.length < 10
      raise ValidationError, "Payment method #{index + 1} has invalid token format"
    end

    # Check for obviously fake tokens (simplified)
    if token =~ /^test_|fake|dummy/i
      raise ValidationError, "Payment method #{index + 1} appears to be a test token"
    end

    { success: true }
  end

  def validate_duplicate_detection(method_data, payment_account, index)
    # Check for duplicate payment methods
    existing_methods = payment_account.payment_methods || []

    existing_methods.each_with_index do |existing_method, existing_index|
      if existing_method[:token] == method_data[:token] && existing_method[:type] == method_data[:type]
        raise ValidationError, "Payment method #{index + 1} is a duplicate of method #{existing_index + 1}"
      end
    end

    { success: true }
  end

  def validate_fraud_indicators(method_data, payment_account, index)
    fraud_service = FraudDetectionService.new

    # Quick fraud check on payment method
    fraud_score = fraud_service.quick_fraud_check(method_data)

    if fraud_score > 0.8
      raise ValidationError, "Payment method #{index + 1} has high fraud indicators (score: #{fraud_score})"
    end

    { success: true }
  end

  def validate_cross_method_rules(payment_methods_data, payment_account)
    # Validate rules that apply across all payment methods

    # Check for too many methods of same type
    type_counts = payment_methods_data.group_by { |method| method[:type] }.transform_values(&:count)
    max_per_type = 3

    type_counts.each do |type, count|
      if count > max_per_type
        return {
          success: false,
          errors: ["Too many #{type} methods: #{count} (max: #{max_per_type})"],
          rule_type: :cross_method_limit
        }
      end
    end

    # Check for suspicious patterns across methods
    suspicious_patterns = detect_suspicious_patterns(payment_methods_data)
    if suspicious_patterns.any?
      return {
        success: false,
        errors: ["Suspicious patterns detected: #{suspicious_patterns.join(', ')}"],
        rule_type: :suspicious_pattern
      }
    end

    { success: true, validation_details: 'Cross-method validation passed' }
  end

  def detect_suspicious_patterns(payment_methods_data)
    patterns = []

    # Check for sequential card numbers (simplified)
    card_methods = payment_methods_data.select { |m| %w[credit_card debit_card].include?(m[:type]) }
    if card_methods.size > 2
      last_fours = card_methods.map { |m| m[:last_four] }.sort
      # Check for sequential patterns (simplified check)
      if last_fours.each_cons(2).any? { |a, b| (b.to_i - a.to_i).abs == 1 }
        patterns << 'sequential_card_numbers'
      end
    end

    # Check for same billing address patterns
    addresses = payment_methods_data.map { |m| m[:billing_address] }.compact
    if addresses.size > 1 && addresses.uniq.size == 1
      patterns << 'identical_billing_addresses'
    end

    patterns
  end
end