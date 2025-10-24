# frozen_string_literal: true

# Command: Update Payment Methods
# Handles payment method updates with fraud detection and validation
class PaymentAccountCommands::UpdatePaymentMethodsCommand
  include CommandPattern

  attr_reader :payment_account_id, :payment_methods_data, :request_id

  def initialize(payment_account_id:, payment_methods_data:, request_id:)
    @payment_account_id = payment_account_id
    @payment_methods_data = payment_methods_data
    @request_id = request_id

    validate!
  end

  def execute
    validate_execution!

    ActiveRecord::Base.transaction(isolation: :serializable) do
      # Execute fraud detection on new payment methods
      fraud_assessment = execute_fraud_assessment

      # Validate payment methods
      validation_result = validate_payment_methods
      return failure_result(validation_result.error) unless validation_result.success?

      # Create domain event
      event = create_update_event(fraud_assessment, validation_result)
      store_event(event)

      # Update read model
      update_payment_methods(event)

      # Publish to event bus
      publish_event(event)

      # Trigger security workflows
      trigger_security_workflows(event)

      success_result(event, 'Payment methods updated successfully')
    end
  rescue ActiveRecord::RecordInvalid => e
    failure_result("Invalid payment methods update: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("Payment methods update failed for account #{payment_account_id}: #{e.message}")
    failure_result("Payment methods update failed: #{e.message}")
  end

  private

  def validate!
    raise ValidationError, 'Payment account ID is required' unless payment_account_id.present?
    raise ValidationError, 'Payment methods data is required' unless payment_methods_data.present?
    raise ValidationError, 'Request ID is required' unless request_id.present?
    validate_payment_methods_structure
  end

  def validate_execution!
    @payment_account = PaymentAccount.find_by(id: payment_account_id)
    raise ValidationError, 'Payment account not found' unless @payment_account
    raise ValidationError, 'Account is suspended' if @payment_account.suspended?
    raise ValidationError, 'Account is terminated' if @payment_account.terminated?
  end

  def validate_payment_methods_structure
    unless payment_methods_data.is_a?(Array) && payment_methods_data.all? { |pm| pm.is_a?(Hash) }
      raise ValidationError, 'Payment methods must be an array of hashes'
    end

    required_fields = %i[type token last_four]
    payment_methods_data.each_with_index do |pm, index|
      missing_fields = required_fields.select { |field| pm[field].blank? }
      raise ValidationError, "Payment method #{index + 1} missing: #{missing_fields.join(', ')}" if missing_fields.any?
    end
  end

  def execute_fraud_assessment
    fraud_service = FraudDetectionService.new
    fraud_service.execute_assessment(@payment_account, {
      operation: :payment_method_update,
      payment_methods: payment_methods_data,
      request_id: request_id
    })
  end

  def validate_payment_methods
    validator = PaymentMethodValidator.new
    validator.validate_methods(payment_methods_data, @payment_account)
  end

  def create_update_event(fraud_assessment, validation_result)
    aggregate_id = "payment_account_#{payment_account_id}"

    PaymentMethodsUpdatedEvent.new(
      aggregate_id,
      payment_account_id: payment_account_id,
      payment_methods_data: payment_methods_data,
      fraud_assessment_score: fraud_assessment.score,
      validation_results: validation_result.data,
      update_metadata: {
        risk_level: @payment_account.risk_level,
        fraud_score: fraud_assessment.score,
        validation_passed: validation_result.success?,
        methods_count: payment_methods_data.size
      },
      request_id: request_id
    )
  end

  def store_event(event)
    event_store = EventStore.new
    event_store.append_events(event.aggregate_id, [event])
  end

  def update_payment_methods(event)
    @payment_account.update!(
      payment_methods: payment_methods_data,
      last_payment_method_update: Time.current,
      payment_method_metadata: event.update_metadata
    )
  end

  def publish_event(event)
    EventPublisher.publish('payment_account.events', event)
    EventPublisher.publish('security.events', event) if event.fraud_assessment_score > 0.7
  end

  def trigger_security_workflows(event)
    # Trigger async security validation if high risk
    if event.fraud_assessment_score > 0.7
      SecurityValidationJob.perform_async(payment_account_id, :payment_methods_update)
    end

    # Monitor for suspicious activity
    PaymentActivityMonitorJob.perform_async(payment_account_id, :methods_updated)
  end
end