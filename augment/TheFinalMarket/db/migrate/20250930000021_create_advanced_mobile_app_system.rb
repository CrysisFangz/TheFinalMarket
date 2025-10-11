class CreateAdvancedMobileAppSystem < ActiveRecord::Migration[8.0]
  def change
    # Mobile Wallet
    create_table :mobile_wallets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :wallet_id, null: false
      t.integer :balance_cents, default: 0
      t.integer :status, default: 0
      t.datetime :activated_at
      t.datetime :suspended_at
      t.string :suspension_reason
      t.jsonb :wallet_data, default: {}
      t.timestamps
    end
    
    create_table :wallet_cards do |t|
      t.references :mobile_wallet, null: false, foreign_key: true
      t.integer :card_type, null: false
      t.integer :card_brand
      t.string :last_four, null: false
      t.integer :expiry_month
      t.integer :expiry_year
      t.string :cardholder_name
      t.boolean :is_default, default: false
      t.string :token
      t.integer :status, default: 0
      t.datetime :removed_at
      t.jsonb :card_data, default: {}
      t.timestamps
    end
    
    create_table :wallet_transactions do |t|
      t.references :mobile_wallet, null: false, foreign_key: true
      t.integer :transaction_type, null: false
      t.integer :amount_cents, null: false
      t.integer :balance_after_cents, null: false
      t.string :source
      t.string :purpose
      t.integer :status, default: 1
      t.datetime :processed_at
      t.jsonb :transaction_data, default: {}
      t.timestamps
    end
    
    create_table :wallet_passes do |t|
      t.references :mobile_wallet, null: false, foreign_key: true
      t.integer :pass_type, null: false
      t.string :pass_name, null: false
      t.string :pass_identifier, null: false
      t.string :barcode_value
      t.integer :barcode_format
      t.date :expiry_date
      t.integer :status, default: 0
      t.datetime :redeemed_at
      t.datetime :removed_at
      t.datetime :added_at
      t.jsonb :pass_data, default: {}
      t.timestamps
    end
    
    # Offline Sync
    create_table :offline_syncs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :mobile_device, null: false, foreign_key: true
      t.integer :sync_type, null: false
      t.integer :sync_status, default: 0
      t.jsonb :action_data, default: {}
      t.jsonb :sync_result, default: {}
      t.datetime :queued_at
      t.datetime :sync_started_at
      t.datetime :sync_completed_at
      t.integer :retry_count, default: 0
      t.string :error_message
      t.timestamps
    end
    
    # Geolocation
    create_table :geolocation_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :mobile_device, foreign_key: true
      t.references :store_location, foreign_key: true
      t.integer :event_type, null: false
      t.decimal :latitude, precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.decimal :accuracy, precision: 10, scale: 2
      t.decimal :altitude, precision: 10, scale: 2
      t.decimal :speed, precision: 10, scale: 2
      t.decimal :heading, precision: 10, scale: 2
      t.datetime :recorded_at, null: false
      t.jsonb :event_data, default: {}
      t.timestamps
    end
    
    create_table :store_locations do |t|
      t.string :name, null: false
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :phone
      t.decimal :latitude, precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.integer :store_type, default: 0
      t.integer :status, default: 0
      t.jsonb :operating_hours, default: {}
      t.jsonb :store_data, default: {}
      t.timestamps
    end
    
    # Camera Captures
    create_table :camera_captures do |t|
      t.references :user, null: false, foreign_key: true
      t.references :mobile_device, foreign_key: true
      t.references :product, foreign_key: true
      t.integer :capture_type, null: false
      t.string :image_url
      t.integer :image_size
      t.string :image_format
      t.integer :processing_status, default: 0
      t.datetime :captured_at, null: false
      t.datetime :processing_started_at
      t.datetime :processing_completed_at
      t.jsonb :capture_data, default: {}
      t.jsonb :processing_result, default: {}
      t.string :error_message
      t.timestamps
    end
    
    # Biometric Authentication
    create_table :biometric_authentications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :mobile_device, null: false, foreign_key: true
      t.integer :biometric_type, null: false
      t.string :biometric_hash, null: false
      t.integer :status, default: 0
      t.datetime :enrolled_at
      t.datetime :last_verified_at
      t.datetime :disabled_at
      t.integer :verification_count, default: 0
      t.integer :failed_attempts, default: 0
      t.timestamps
    end
    
    # Indexes
    add_index :mobile_wallets, :wallet_id, unique: true
    add_index :mobile_wallets, :status
    
    add_index :wallet_cards, [:mobile_wallet_id, :is_default]
    add_index :wallet_cards, :status
    
    add_index :wallet_transactions, [:mobile_wallet_id, :processed_at]
    add_index :wallet_transactions, :transaction_type
    
    add_index :wallet_passes, [:mobile_wallet_id, :pass_identifier], unique: true, name: 'index_wallet_passes_on_wallet_and_identifier'
    add_index :wallet_passes, :pass_type
    add_index :wallet_passes, :status
    
    add_index :offline_syncs, [:user_id, :sync_status]
    add_index :offline_syncs, [:mobile_device_id, :sync_status]
    add_index :offline_syncs, :sync_type
    
    add_index :geolocation_events, [:user_id, :recorded_at]
    add_index :geolocation_events, [:latitude, :longitude]
    add_index :geolocation_events, :event_type
    
    add_index :store_locations, [:latitude, :longitude]
    add_index :store_locations, :status
    
    add_index :camera_captures, [:user_id, :captured_at]
    add_index :camera_captures, :capture_type
    add_index :camera_captures, :processing_status
    
    add_index :biometric_authentications, [:user_id, :mobile_device_id, :biometric_type], unique: true, name: 'index_biometric_auth_on_user_device_type'
    add_index :biometric_authentications, :status
  end
end

