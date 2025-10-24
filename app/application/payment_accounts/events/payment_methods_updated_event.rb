# frozen_string_literal: true

# Domain Event: Payment Methods Updated
# Immutable event representing payment method updates
class PaymentMethodsUpdatedEvent < DomainEvent
  attr_reader :payment_account_id, :payment_methods_data, :fraud_assessment_score,
              :validation_results, :update_metadata, :request_id

  def initialize(aggregate_id, payment_account_id:, payment_methods_data:, fraud_assessment_score:,
                 validation_results:, update_metadata:, request_id:)
    super(aggregate_id, SecureRandom.uuid, Time.current)

    @payment_account_id = payment_account_id
    @payment_methods_data = payment_methods_data
    @fraud_assessment_score = fraud_assessment_score
    @validation_results = validation_results
    @update_metadata = update_metadata
    @request_id = request_id

    validate!
  end

  def event_type
    'PaymentMethodsUpdated'
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
      payment_methods_data: payment_methods_data,
      fraud_assessment_score: fraud_assessment_score,
      validation_results: validation_results,
      update_metadata: update_metadata,
      request_id: request_id
    )
  end

  def to_json(options = {})
    to_h.to_json(options)
  end

  def high_risk_update?
    fraud_assessment_score > 0.7
  end

  def validation_passed?
    validation_results.all? { |result| result[:success] }
  end

  def payment_methods_count
    payment_methods_data.size
  end

  private

  def validate!
    raise ValidationError, 'Payment account ID is required' unless payment_account_id.present?
    raise ValidationError, 'Payment methods data is required' unless payment_methods_data.present?
    raise ValidationError, 'Request ID is required' unless request_id.present?
    raise ValidationError, 'Fraud assessment score is required' unless fraud_assessment_score.present?
  end
end