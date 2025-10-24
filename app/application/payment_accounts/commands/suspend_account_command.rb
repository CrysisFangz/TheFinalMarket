# frozen_string_literal: true

# Command: Suspend Payment Account
# Handles payment account suspension with compliance validation and audit trail
class PaymentAccountCommands::SuspendAccountCommand
  include CommandPattern

  attr_reader :payment_account_id, :suspension_reason, :admin_user_id, :request_id

  def initialize(payment_account_id:, suspension_reason:, admin_user_id: nil, request_id:)
    @payment_account_id = payment_account_id
    @suspension_reason = suspension_reason
    @admin_user_id = admin_user_id
    @request_id = request_id

    validate!
  end

  def execute
    validate_execution!

    ActiveRecord::Base.transaction(isolation: :serializable) do
      # Execute fraud detection before suspension
      fraud_assessment = execute_fraud_assessment

      # Create domain event
      event = create_suspension_event(fraud_assessment)
      store_event(event)

      # Update read model
      update_account_status(event)

      # Publish to event bus
      publish_event(event)

      # Trigger compliance workflows
      trigger_compliance_workflows(event)

      success_result(event, 'Payment account suspended successfully')
    end
  rescue ActiveRecord::RecordInvalid => e
    failure_result("Invalid account suspension: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("Payment account suspension failed for account #{payment_account_id}: #{e.message}")
    failure_result("Account suspension failed: #{e.message}")
  end

  private

  def validate!
    raise ValidationError, 'Payment account ID is required' unless payment_account_id.present?
    raise ValidationError, 'Suspension reason is required' unless suspension_reason.present?
    raise ValidationError, 'Request ID is required' unless request_id.present?
  end

  def validate_execution!
    @payment_account = PaymentAccount.find_by(id: payment_account_id)
    raise ValidationError, 'Payment account not found' unless @payment_account
    raise ValidationError, 'Account is already suspended' if @payment_account.suspended?
    raise ValidationError, 'Account is terminated' if @payment_account.terminated?
  end

  def execute_fraud_assessment
    fraud_service = FraudDetectionService.new
    fraud_service.execute_assessment(@payment_account, {
      operation: :account_suspension,
      reason: suspension_reason,
      admin_user_id: admin_user_id
    })
  end

  def create_suspension_event(fraud_assessment)
    aggregate_id = "payment_account_#{payment_account_id}"

    PaymentAccountSuspendedEvent.new(
      aggregate_id,
      payment_account_id: payment_account_id,
      suspension_reason: suspension_reason,
      admin_user_id: admin_user_id,
      fraud_assessment_score: fraud_assessment.score,
      compliance_flags: fraud_assessment.compliance_flags,
      suspension_metadata: {
        risk_level: @payment_account.risk_level,
        fraud_score: fraud_assessment.score,
        compliance_violations: fraud_assessment.violations
      },
      request_id: request_id
    )
  end

  def store_event(event)
    event_store = EventStore.new
    event_store.append_events(event.aggregate_id, [event])
  end

  def update_account_status(event)
    @payment_account.update!(
      status: :suspended,
      suspended_at: Time.current,
      suspension_reason: suspension_reason,
      suspension_metadata: event.suspension_metadata
    )
  end

  def publish_event(event)
    EventPublisher.publish('payment_account.events', event)
    EventPublisher.publish('compliance.events', event)
  end

  def trigger_compliance_workflows(event)
    # Trigger async compliance validation
    ComplianceValidationJob.perform_async(payment_account_id, :suspension)

    # Notify relevant parties
    NotificationService.notify(
      recipient: @payment_account.user,
      action: :account_suspended,
      notifiable: @payment_account,
      metadata: { reason: suspension_reason }
    )
  end
end