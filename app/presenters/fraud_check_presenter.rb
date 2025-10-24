class FraudCheckPresenter
  def initialize(fraud_check)
    @fraud_check = fraud_check
  end

  def as_json(options = {})
    {
      id: @fraud_check.id,
      checkable_type: @fraud_check.checkable_type,
      checkable_id: @fraud_check.checkable_id,
      user_id: @fraud_check.user_id,
      check_type: @fraud_check.check_type,
      risk_score: @fraud_check.risk_score,
      risk_level: @fraud_check.risk_level,
      action_taken: @fraud_check.action_taken,
      factors: @fraud_check.factors,
      flagged: @fraud_check.flagged?,
      created_at: @fraud_check.created_at,
      updated_at: @fraud_check.updated_at,
      high_risk: @fraud_check.high_risk?,
      requires_action: @fraud_check.requires_action?,
      risk_description: @fraud_check.risk_description,
      risk_factors_array: @fraud_check.risk_factors_array
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end