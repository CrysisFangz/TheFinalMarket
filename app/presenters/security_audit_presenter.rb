class SecurityAuditPresenter
  def initialize(audit)
    @audit = audit
  end

  def as_json(options = {})
    {
      id: @audit.id,
      event_type: @audit.event_type,
      severity: @audit.severity,
      user_id: @audit.user_id,
      ip_address: @audit.ip_address,
      user_agent: @audit.user_agent,
      event_details: @audit.event_details,
      occurred_at: @audit.occurred_at,
      created_at: @audit.created_at,
      updated_at: @audit.updated_at
    }
  end

  def to_json(*options)
    as_json(*options).to_json
  end
end