# =============================================================================
# AuditStartedEvent - Event for Audit Execution Lifecycle
# =============================================================================

class AccessibilityAudit::AuditStartedEvent < AccessibilityAudit::AuditEvent
  # Define schema for audit started event
  def self.define_event_schema
    {
      type: :object,
      required: [:event_id, :event_type, :aggregate_id, :timestamp, :page_url, :audit_type],
      properties: {
        event_id: { type: :string },
        event_type: { type: :string },
        aggregate_id: { type: :string },
        aggregate_type: { type: :string },
        causation_id: { type: :string },
        correlation_id: { type: :string },
        timestamp: { type: :string, format: :datetime },
        version: { type: :integer },
        event_data: {
          type: :object,
          properties: {
            page_url: { type: :string },
            audit_type: { type: :string },
            wcag_level: { type: :string },
            audit_scope: { type: :string },
            user_id: { type: :integer },
            options: { type: :object }
          },
          required: [:page_url, :audit_type]
        },
        metadata: { type: :object }
      }
    }
  end

  # Apply event to audit aggregate for state reconstruction
  def apply_to(audit)
    audit.status = :running
    audit.started_at = timestamp
    audit.audit_type = event_data[:audit_type]
    audit.wcag_level = event_data[:wcag_level]
    audit.audit_scope = event_data[:audit_scope]
    audit.user_id = event_data[:user_id]
    audit.metadata = metadata

    audit
  end
end