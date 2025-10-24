# Concern for audit trails
module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_trails, as: :auditable, dependent: :destroy
    after_create :create_audit_trail
    after_update :create_audit_trail_on_change
    after_destroy :create_audit_trail_on_destroy
  end

  def audit_changes
    changes.except('updated_at')
  end

  private

  def create_audit_trail
    AuditTrail.create!(
      auditable: self,
      action: self.class.name.underscore,
      changes: audit_changes,
      user_id: user_id,
      metadata: { source: 'system' }
    )
  end

  def create_audit_trail_on_change
    return unless saved_changes?

    AuditTrail.create!(
      auditable: self,
      action: 'update',
      changes: saved_changes.except('updated_at'),
      user_id: user_id,
      metadata: { source: 'system' }
    )
  end

  def create_audit_trail_on_destroy
    AuditTrail.create!(
      auditable: self,
      action: 'destroy',
      changes: attributes,
      user_id: user_id,
      metadata: { source: 'system' }
    )
  end
end