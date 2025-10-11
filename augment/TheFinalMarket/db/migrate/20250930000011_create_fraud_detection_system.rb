class CreateFraudDetectionSystem < ActiveRecord::Migration[8.0]
  def change
    # Fraud Checks
    create_table :fraud_checks do |t|
      t.references :user, foreign_key: true
      t.references :checkable, polymorphic: true, null: false
      
      t.integer :check_type, null: false, default: 0
      t.integer :risk_score, null: false, default: 0
      t.integer :risk_level, default: 0
      
      t.jsonb :factors, default: {}
      
      t.string :ip_address
      t.string :user_agent
      t.string :device_id
      
      t.boolean :flagged, default: false
      t.integer :action_taken, default: 0
      
      t.text :notes
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :fraud_checks, [:user_id, :created_at]
    add_index :fraud_checks, [:checkable_type, :checkable_id]
    add_index :fraud_checks, :check_type
    add_index :fraud_checks, :risk_score
    add_index :fraud_checks, :risk_level
    add_index :fraud_checks, :flagged
    add_index :fraud_checks, :ip_address
    add_index :fraud_checks, :created_at
    
    # Trust Scores
    create_table :trust_scores do |t|
      t.references :user, null: false, foreign_key: true
      
      t.integer :score, null: false, default: 50
      t.integer :trust_level, default: 2
      
      t.jsonb :factors, default: {}
      t.jsonb :calculation_details, default: {}
      
      t.timestamps
    end
    
    add_index :trust_scores, [:user_id, :created_at]
    add_index :trust_scores, :score
    add_index :trust_scores, :trust_level
    
    # Device Fingerprints
    create_table :device_fingerprints do |t|
      t.references :user, foreign_key: true
      
      t.string :fingerprint_hash, null: false
      t.jsonb :device_info, default: {}
      
      t.string :last_ip_address
      t.datetime :last_seen_at
      t.integer :access_count, default: 0
      
      t.boolean :suspicious, default: false
      t.string :suspicious_reason
      t.datetime :suspicious_at
      
      t.boolean :blocked, default: false
      t.string :blocked_reason
      t.datetime :blocked_at
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :device_fingerprints, :fingerprint_hash, unique: true
    add_index :device_fingerprints, :user_id
    add_index :device_fingerprints, :last_ip_address
    add_index :device_fingerprints, :suspicious
    add_index :device_fingerprints, :blocked
    add_index :device_fingerprints, :last_seen_at
    
    # Behavioral Patterns
    create_table :behavioral_patterns do |t|
      t.references :user, null: false, foreign_key: true
      
      t.integer :pattern_type, null: false, default: 0
      t.boolean :anomalous, default: false
      
      t.jsonb :pattern_data, default: {}
      t.datetime :detected_at
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :behavioral_patterns, [:user_id, :pattern_type]
    add_index :behavioral_patterns, :anomalous
    add_index :behavioral_patterns, :detected_at
    
    # IP Blacklist
    create_table :ip_blacklists do |t|
      t.string :ip_address, null: false
      t.string :reason
      t.integer :severity, default: 1 # 1: low, 2: medium, 3: high
      
      t.datetime :expires_at
      t.boolean :permanent, default: false
      
      t.string :added_by
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :ip_blacklists, :ip_address, unique: true
    add_index :ip_blacklists, :severity
    add_index :ip_blacklists, :expires_at
    
    # Fraud Rules
    create_table :fraud_rules do |t|
      t.string :name, null: false
      t.text :description
      
      t.integer :rule_type, null: false, default: 0
      t.jsonb :conditions, default: {}
      t.integer :risk_weight, default: 10
      
      t.boolean :active, default: true
      t.integer :priority, default: 100
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :fraud_rules, :rule_type
    add_index :fraud_rules, :active
    add_index :fraud_rules, :priority
    
    # Fraud Alerts
    create_table :fraud_alerts do |t|
      t.references :fraud_check, null: false, foreign_key: true
      t.references :user, foreign_key: true
      
      t.integer :alert_type, null: false, default: 0
      t.integer :severity, null: false, default: 1
      
      t.string :title
      t.text :message
      
      t.boolean :acknowledged, default: false
      t.datetime :acknowledged_at
      t.references :acknowledged_by, foreign_key: { to_table: :users }
      
      t.boolean :resolved, default: false
      t.datetime :resolved_at
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.text :resolution_notes
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :fraud_alerts, [:user_id, :created_at]
    add_index :fraud_alerts, :alert_type
    add_index :fraud_alerts, :severity
    add_index :fraud_alerts, :acknowledged
    add_index :fraud_alerts, :resolved
    
    # Add columns to users table
    add_column :users, :email_verified, :boolean, default: false
    add_column :users, :email_verified_at, :datetime
    add_column :users, :phone_verified, :boolean, default: false
    add_column :users, :phone_verified_at, :datetime
    add_column :users, :identity_verified, :boolean, default: false
    add_column :users, :identity_verified_at, :datetime
    add_column :users, :fraud_score, :integer, default: 0
    add_column :users, :trust_score, :integer, default: 50
    add_column :users, :suspension_count, :integer, default: 0
    
    add_index :users, :email_verified
    add_index :users, :phone_verified
    add_index :users, :identity_verified
    add_index :users, :fraud_score
    add_index :users, :trust_score
    
    # Add columns to orders table
    add_column :orders, :fraud_check_score, :integer, default: 0
    add_column :orders, :fraud_checked_at, :datetime
    add_column :orders, :requires_manual_review, :boolean, default: false
    
    add_index :orders, :fraud_check_score
    add_index :orders, :requires_manual_review
  end
end

