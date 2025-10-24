# frozen_string_literal: true

# Domain Event: Payment Account Suspended
# Immutable event representing payment account suspension
class PaymentAccountSuspendedEvent < DomainEvent
  attr_reader :payment_account_id, :suspension_reason, :admin_user_id, :fraud_assessment_score,
              :compliance_flags, :suspension_metadata, :request_id

  def initialize(aggregate_id, payment_account_id:, suspension_reason:, admin_user_id:,
                 fraud_assessment_score:, compliance_flags:, suspension_metadata:, request_id:)
    super(aggregate_id, SecureRandom.uuid, Time.current)

    @payment_account_id = payment_account_id
    @suspension_reason = suspension_reason
    @admin_user_id = admin_user_id
    @fraud_assessment_score = fraud_assessment_score
    @compliance_flags = compliance_flags
    @suspension_metadata = suspension_metadata
    @request_id = request_id

    validate!
  end

  def event_type
    'PaymentAccountSuspended'
  end

  def aggregate_type
    'PaymentAccount'
  end

  def event_version
    1
  end

  def to_h
    super.merge(
      payment_account_id: payment_account_id,
      suspension_reason: suspension_reason,
      admin_user_id: admin_user_id,
      fraud_assessment_score: fraud_assessment_score,
      compliance_flags: compliance_flags,
      suspension_metadata: suspension_metadata,
      request_id: request_id
    )
  end

  def to_json(options = {})
    to_h.to_json(options)
  end

  def high_risk?
    fraud_assessment_score > 0.8
  end

  def compliance_violations?
    compliance_flags.any?
  end

  private

  def validate!
    raise ValidationError, 'Payment account ID is required' unless payment_account_id.present?
    raise ValidationError, 'Suspension reason is required' unless suspension_reason.present?
    raise ValidationError, 'Request ID is required' unless request_id.present?
    raise ValidationError, 'Fraud assessment score is required' unless fraud_assessment_score.present?
  end
end