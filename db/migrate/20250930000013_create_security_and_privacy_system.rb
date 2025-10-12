class CreateSecurityAndPrivacySystem < ActiveRecord::Migration[8.0]
  def change
    # Two-Factor Authentication
    create_table :two_factor_authentications do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :auth_method, null: false, default: 0
      t.string :secret_key # Encrypted
      t.text :backup_codes # Encrypted
      t.boolean :enabled, default: false
      t.string :verification_code
      t.datetime :verification_code_sent_at
      t.datetime :last_used_at
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index :auth_method
      t.index :enabled
      t.index [:user_id, :auth_method], unique: true
    end
    
    # Privacy Settings
    create_table :privacy_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :data_processing_consent, default: false
      t.boolean :marketing_consent, default: false
      t.integer :data_retention_period, default: 1
      t.jsonb :data_sharing_preferences, default: {}
      t.jsonb :marketing_preferences, default: {}
      t.jsonb :visibility_preferences, default: {}
      t.datetime :consent_given_at
      t.datetime :consent_updated_at
      
      t.timestamps
      
      t.index :data_processing_consent
      t.index :marketing_consent
    end
    
    # Identity Verification
    create_table :identity_verifications do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :verification_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :document_type
      t.string :document_number
      t.date :document_expiry
      t.datetime :submitted_at
      t.datetime :verified_at
      t.datetime :expires_at
      t.integer :reviewed_by
      t.datetime :reviewed_at
      t.text :rejection_reason
      t.jsonb :verification_results, default: {}
      t.boolean :requires_manual_review, default: false
      
      t.timestamps
      
      t.index :verification_type
      t.index :status
      t.index :verified_at
      t.index :expires_at
    end
    
    # Encrypted Messages
    create_table :encrypted_messages do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :conversation, foreign_key: true
      t.text :encrypted_content # Encrypted
      t.string :subject # Encrypted
      t.integer :message_type, default: 0
      t.datetime :read_at
      t.datetime :encrypted_at
      t.boolean :deleted_by_sender, default: false
      t.boolean :deleted_by_recipient, default: false
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index :sender_id
      t.index :recipient_id
      t.index :conversation_id
      t.index :message_type
      t.index :read_at
      t.index :created_at
    end
    
    # Message Reads
    create_table :message_reads do |t|
      t.references :encrypted_message, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :read_at, null: false
      
      t.timestamps
      
      t.index [:encrypted_message_id, :user_id], unique: true
    end
    
    # Message Attachments
    create_table :message_attachments do |t|
      t.references :encrypted_message, null: false, foreign_key: true
      t.string :file_name
      t.string :file_type
      t.integer :file_size_bytes
      t.string :encryption_key
      
      t.timestamps
    end
    
    # Message Reports
    create_table :message_reports do |t|
      t.references :encrypted_message, null: false, foreign_key: true
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.text :reason
      t.integer :status, default: 0
      t.datetime :reported_at
      t.datetime :resolved_at
      t.integer :resolved_by
      
      t.timestamps
      
      t.index :status
      t.index :reported_at
    end
    
    # Purchase Protection
    create_table :purchase_protections do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :protection_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :coverage_amount_cents, null: false
      t.integer :premium_cents, null: false
      t.datetime :starts_at
      t.datetime :expires_at
      t.jsonb :terms, default: {}
      
      t.timestamps
      
      t.index :protection_type
      t.index :status
      t.index :expires_at
    end
    
    # Protection Claims
    create_table :protection_claims do |t|
      t.references :purchase_protection, null: false, foreign_key: true
      t.integer :reason, null: false
      t.text :description
      t.integer :claim_amount_cents, null: false
      t.integer :approved_amount_cents
      t.integer :status, null: false, default: 0
      t.datetime :filed_at
      t.datetime :reviewed_at
      t.integer :reviewed_by
      t.datetime :paid_at
      t.text :resolution_notes
      t.jsonb :evidence, default: {}
      
      t.timestamps
      
      t.index :reason
      t.index :status
      t.index :filed_at
    end
    
    # Security Audits
    create_table :security_audits do |t|
      t.references :user, foreign_key: true
      t.integer :event_type, null: false
      t.integer :severity, null: false, default: 0
      t.string :ip_address
      t.string :user_agent
      t.jsonb :event_details, default: {}
      t.datetime :occurred_at, null: false
      t.boolean :alerted, default: false
      
      t.timestamps
      
      t.index :event_type
      t.index :severity
      t.index :occurred_at
      t.index :ip_address
      t.index [:user_id, :event_type]
      t.index [:user_id, :occurred_at]
    end
    
    # Add security columns to users table
    add_column :users, :two_factor_enabled, :boolean, default: false
    add_column :users, :identity_verified, :boolean, default: false
    add_column :users, :verification_level, :integer, default: 0
    add_column :users, :password_changed_at, :datetime
    add_column :users, :account_locked_at, :datetime
    add_column :users, :account_locked_reason, :string
    add_column :users, :failed_login_attempts, :integer, default: 0
    add_column :users, :last_failed_login_at, :datetime
    add_column :users, :security_score, :integer, default: 100
    
    add_index :users, :two_factor_enabled
    add_index :users, :identity_verified
    add_index :users, :verification_level
    add_index :users, :account_locked_at
  end
end

