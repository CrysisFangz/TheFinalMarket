# frozen_string_literal: true

# Domain Event: Payment Account Activated
# Immutable event representing payment account activation
class PaymentAccountActivatedEvent < DomainEvent
  attr_reader :payment_account_id, :activation_reason, :admin_user_id, :activation_metadata, :request_id

  def initialize(aggregate_id, payment_account_id:, activation_reason:, admin_user_id:, activation_metadata:, request_id:)
    super(aggregate_id, SecureRandom.uuid, Time.current)

    @payment_account_id = payment_account_id
    @activation_reason = activation_reason
    @admin_user_id = admin_user_id
    @activation_metadata = activation_metadata
    @request_id = request_id

    validate!
  end

  def event_type
    'PaymentAccountActivated'
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
      activation_reason: activation_reason,
      admin_user_id: admin_user_id,
      activation_metadata: activation_metadata,
      request_id: request_id
    )
  end

  def to_json(options = {})
    to_h.to_json(options)
  end

  private

  def validate!
    raise ValidationError, 'Payment account ID is required' unless payment_account_id.present?
    raise ValidationError, 'Activation reason is required' unless activation_reason.present?
    raise ValidationError, 'Request ID is required' unless request_id.present?
  end
end