class FraudAlertPresenter
  def initialize(alert)
    @alert = alert
  end

  def as_json(options = {})
    {
      id: @alert.id,
      fraud_check_id: @alert.fraud_check_id,
      user_id: @alert.user_id,
      alert_type: @alert.alert_type,
      severity: @alert.severity,
      description: @alert.description,
      metadata: @alert.metadata,
      acknowledged: @alert.acknowledged?,
      acknowledged_at: @alert.acknowledged_at,
      acknowledged_by_id: @alert.acknowledged_by_id,
      resolved: @alert.resolved?,
      resolved_at: @alert.resolved_at,
      resolved_by_id: @alert.resolved_by_id,
      resolution_notes: @alert.resolution_notes,
      badge_color: @alert.badge_color,
      critical: @alert.critical?,
      created_at: @alert.created_at,
      updated_at: @alert.updated_at
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end