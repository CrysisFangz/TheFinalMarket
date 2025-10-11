# db/migrate/20250930000020_create_mobile_app_system.rb
class CreateMobileAppSystem < ActiveRecord::Migration[8.0]
  def change
    # Barcode scans table
    create_table :barcode_scans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: true, foreign_key: true
      t.string :barcode, null: false
      t.string :product_name
      t.datetime :scanned_at, null: false
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index :barcode
      t.index :scanned_at
      t.index [:user_id, :scanned_at]
    end
    
    # Push subscriptions table
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :endpoint, null: false
      t.text :p256dh_key, null: false
      t.text :auth_key, null: false
      t.string :device_type
      t.boolean :active, default: true
      t.datetime :last_used_at
      
      t.timestamps
      
      t.index :endpoint, unique: true
      t.index :active
      t.index [:user_id, :active]
    end
    
    # Mobile devices table
    create_table :mobile_devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :device_id, null: false
      t.integer :device_type, null: false, default: 0
      t.string :device_name
      t.string :os_version
      t.string :app_version
      t.integer :status, default: 0
      t.datetime :last_seen_at
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index [:user_id, :device_id], unique: true
      t.index :device_type
      t.index :status
      t.index :last_seen_at
    end
    
    # Product suggestions from barcode scans
    create_table :product_suggestions do |t|
      t.string :name, null: false
      t.string :barcode
      t.text :description
      t.string :brand
      t.string :category
      t.string :image_url
      t.integer :status, default: 0 # pending, approved, rejected
      t.jsonb :external_data, default: {}
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      
      t.timestamps
      
      t.index :barcode
      t.index :status
      t.index :created_at
    end
    
    # Add biometric auth fields to users table
    add_column :users, :biometric_credential_id, :string
    add_column :users, :biometric_public_key, :text
    add_column :users, :last_biometric_auth_at, :datetime
    add_column :users, :latitude, :decimal, precision: 10, scale: 6
    add_column :users, :longitude, :decimal, precision: 10, scale: 6
    add_column :users, :location_updated_at, :datetime
    
    add_index :users, :biometric_credential_id, unique: true
    add_index :users, [:latitude, :longitude]
    
    # Add barcode to products table if not exists
    unless column_exists?(:products, :barcode)
      add_column :products, :barcode, :string
      add_column :products, :primary_color, :string
      add_index :products, :barcode, unique: true
    end
    
    # Stores table for geolocation features
    unless table_exists?(:stores)
      create_table :stores do |t|
        t.string :name, null: false
        t.text :address
        t.decimal :latitude, precision: 10, scale: 6
        t.decimal :longitude, precision: 10, scale: 6
        t.string :phone
        t.string :email
        t.text :description
        t.string :image_url
        t.decimal :rating, precision: 3, scale: 2, default: 0.0
        t.integer :review_count, default: 0
        t.boolean :active, default: true
        t.jsonb :hours, default: {}
        t.jsonb :metadata, default: {}
        
        t.timestamps
        
        t.index [:latitude, :longitude]
        t.index :active
        t.index :rating
      end
    end
    
    # Deals table for local deals
    unless table_exists?(:deals)
      create_table :deals do |t|
        t.references :store, foreign_key: true
        t.references :product, foreign_key: true
        t.string :title, null: false
        t.text :description
        t.decimal :discount_percentage, precision: 5, scale: 2
        t.decimal :original_price, precision: 10, scale: 2
        t.decimal :deal_price, precision: 10, scale: 2
        t.datetime :starts_at
        t.datetime :expires_at
        t.boolean :active, default: true
        t.integer :redemption_limit
        t.integer :redemption_count, default: 0
        t.jsonb :metadata, default: {}
        
        t.timestamps
        
        t.index :active
        t.index :expires_at
        t.index [:active, :expires_at]
      end
    end
    
    # Offline sync queue
    create_table :offline_sync_actions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action_type, null: false
      t.jsonb :action_data, default: {}
      t.integer :status, default: 0 # pending, synced, failed
      t.integer :retry_count, default: 0
      t.text :error_message
      t.datetime :synced_at
      
      t.timestamps
      
      t.index :status
      t.index [:user_id, :status]
      t.index :created_at
    end
  end
end

