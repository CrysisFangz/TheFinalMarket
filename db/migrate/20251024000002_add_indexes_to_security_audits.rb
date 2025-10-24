class AddIndexesToSecurityAudits < ActiveRecord::Migration[7.0]
  def change
    add_index :security_audits, :user_id
    add_index :security_audits, :event_type
    add_index :security_audits, :severity
    add_index :security_audits, :created_at
    add_index :security_audits, :ip_address
    add_index :security_audits, [:user_id, :created_at]
    add_index :security_audits, [:user_id, :event_type]
    add_index :security_audits, [:event_type, :created_at]
  end
end