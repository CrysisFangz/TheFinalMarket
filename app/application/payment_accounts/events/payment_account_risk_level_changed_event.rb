# frozen_string_literal: true

# Domain Event: Payment Account Risk Level Changed
# Immutable event representing payment account risk level changes
class PaymentAccountRiskLevelChangedEvent < DomainEvent
  attr_reader :payment_account_id, :old_risk_level, :new_risk_level, :risk_score, :context, :triggered_by

  def initialize(aggregate_id, payment_account_id:, old_risk_level:, new_risk_level:, risk_score:, context:, triggered_by:)
    super(aggregate_id, SecureRandom.uuid, Time.current)

    @payment_account_id = payment_account_id
    @old_risk_level = old_risk_level
    @new_risk_level = new_risk_level
    @risk_score = risk_score
    @context = context
    @triggered_by = triggered_by

    validate!
  end

  def event_type
    'PaymentAccountRiskLevelChanged'
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
      old_risk_level: old_risk_level,
      new_risk_level: new_risk_level,
      risk_score: risk_score,
      context: context,
      triggered_by: triggered_by
    )
  end

  def to_json(options = {})
    to_h.to_json(options)
  end

  def risk_level_increased?
    risk_level_to_score(new_risk_level) > risk_level_to_score(old_risk_level)
  end

  def risk_level_decreased?
    risk_level_to_score(new_risk_level) < risk_level_to_score(old_risk_level)
  end

  def high_risk?
    risk_level_to_score(new_risk_level) >= 0.8
  end

  def requires_manual_review?
    risk_level_increased? && high_risk?
  end

  private

  def validate!
    raise ValidationError, 'Payment account ID is required' unless payment_account_id.present?
    raise ValidationError, 'Old risk level is required' unless old_risk_level.present?
    raise ValidationError, 'New risk level is required' unless new_risk_level.present?
    raise ValidationError, 'Risk score is required' unless risk_score.present?
  end

  def risk_level_to_score(level)
    scores = { low: 0.15, medium: 0.45, high: 0.7, critical: 0.875, extreme: 0.95 }
    scores[level.to_sym] || 0.0
  end
end