class CreateOmnichannelIntegrationSystem < ActiveRecord::Migration[8.0]
  def change
    # Sales Channels
    create_table :sales_channels do |t|
      t.string :name, null: false
      t.integer :channel_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :description
      
      # Configuration
      t.jsonb :config_data, default: {}
      
      # Timestamps
      t.datetime :enabled_at
      t.datetime :disabled_at
      
      t.timestamps
    end
    
    add_index :sales_channels, :name, unique: true
    add_index :sales_channels, :channel_type
    add_index :sales_channels, :status
    add_index :sales_channels, :config_data, using: :gin
    
    # Channel Products (Product availability per channel)
    create_table :channel_products do |t|
      t.references :sales_channel, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      
      t.boolean :available, default: true
      t.decimal :price_override, precision: 10, scale: 2
      t.integer :inventory_override
      
      # Channel-specific data
      t.jsonb :channel_specific_data, default: {}
      
      t.datetime :last_synced_at
      
      t.timestamps
    end
    
    add_index :channel_products, [:sales_channel_id, :product_id], unique: true
    add_index :channel_products, :available
    add_index :channel_products, :channel_specific_data, using: :gin
    
    # Channel Inventory
    create_table :channel_inventories do |t|
      t.references :sales_channel, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      
      t.integer :quantity, null: false, default: 0
      t.integer :reserved_quantity, null: false, default: 0
      t.integer :low_stock_threshold, default: 10
      
      t.datetime :last_synced_at
      
      t.timestamps
    end
    
    add_index :channel_inventories, [:sales_channel_id, :product_id], unique: true
    add_index :channel_inventories, :quantity
    
    # Omnichannel Customers (Unified customer profiles)
    create_table :omnichannel_customers do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      
      t.datetime :last_interaction_at
      t.jsonb :unified_data, default: {}
      
      t.timestamps
    end
    
    add_index :omnichannel_customers, :unified_data, using: :gin
    
    # Channel Interactions (Customer touchpoints)
    create_table :channel_interactions do |t|
      t.references :omnichannel_customer, null: false, foreign_key: true
      t.references :sales_channel, null: false, foreign_key: true
      
      t.integer :interaction_type, null: false
      t.jsonb :interaction_data, default: {}
      t.datetime :occurred_at, null: false
      
      t.timestamps
    end
    
    add_index :channel_interactions, :interaction_type
    add_index :channel_interactions, :occurred_at
    add_index :channel_interactions, :interaction_data, using: :gin
    add_index :channel_interactions, [:omnichannel_customer_id, :sales_channel_id], 
              name: 'index_interactions_on_customer_and_channel'
    
    # Channel Preferences (Customer preferences per channel)
    create_table :channel_preferences do |t|
      t.references :omnichannel_customer, null: false, foreign_key: true
      t.references :sales_channel, null: false, foreign_key: true
      
      t.jsonb :preferences_data, default: {}
      t.datetime :last_synced_at
      
      t.timestamps
    end
    
    add_index :channel_preferences, [:omnichannel_customer_id, :sales_channel_id], 
              unique: true, name: 'index_preferences_on_customer_and_channel'
    add_index :channel_preferences, :preferences_data, using: :gin
    
    # Cross-Channel Journeys
    create_table :cross_channel_journeys do |t|
      t.references :omnichannel_customer, null: false, foreign_key: true
      t.references :sales_channel, null: false, foreign_key: true # Starting channel
      
      t.integer :intent, null: false
      t.integer :touchpoint_count, default: 1
      t.jsonb :journey_data, default: {}
      
      t.boolean :completed, default: false
      t.string :outcome
      t.integer :duration_seconds
      
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.datetime :last_touchpoint_at
      
      t.timestamps
    end
    
    add_index :cross_channel_journeys, :intent
    add_index :cross_channel_journeys, :completed
    add_index :cross_channel_journeys, :started_at
    add_index :cross_channel_journeys, :journey_data, using: :gin
    
    # Journey Touchpoints
    create_table :journey_touchpoints do |t|
      t.references :cross_channel_journey, null: false, foreign_key: true
      t.references :sales_channel, null: false, foreign_key: true
      
      t.string :action, null: false
      t.jsonb :touchpoint_data, default: {}
      t.datetime :occurred_at, null: false
      
      t.timestamps
    end
    
    add_index :journey_touchpoints, :action
    add_index :journey_touchpoints, :occurred_at
    add_index :journey_touchpoints, :touchpoint_data, using: :gin
    
    # Channel Integrations (Third-party integrations)
    create_table :channel_integrations do |t|
      t.references :sales_channel, null: false, foreign_key: true
      
      t.string :platform_name, null: false
      t.integer :integration_type, null: false
      t.jsonb :credentials, default: {}
      t.jsonb :sync_data, default: {}
      
      t.boolean :active, default: false
      t.integer :sync_status, default: 0
      t.integer :sync_count, default: 0
      t.integer :error_count, default: 0
      t.text :last_error
      
      t.datetime :connected_at
      t.datetime :disconnected_at
      t.datetime :last_sync_at
      t.datetime :last_sync_started_at
      
      t.timestamps
    end
    
    add_index :channel_integrations, :platform_name
    add_index :channel_integrations, :integration_type
    add_index :channel_integrations, :active
    add_index :channel_integrations, :sync_status
    
    # Channel Analytics (Daily metrics per channel)
    create_table :channel_analytics do |t|
      t.references :sales_channel, null: false, foreign_key: true
      t.date :date, null: false
      
      # Metrics
      t.integer :orders_count, default: 0
      t.decimal :revenue, precision: 12, scale: 2, default: 0
      t.decimal :average_order_value, precision: 10, scale: 2, default: 0
      t.integer :unique_customers, default: 0
      t.integer :new_customers, default: 0
      t.integer :returning_customers, default: 0
      t.decimal :conversion_rate, precision: 5, scale: 2, default: 0
      t.decimal :return_rate, precision: 5, scale: 2, default: 0
      t.integer :units_sold, default: 0
      
      t.timestamps
    end
    
    add_index :channel_analytics, [:sales_channel_id, :date], unique: true
    add_index :channel_analytics, :date
    add_index :channel_analytics, :revenue
    
    # Add sales_channel_id to orders table
    add_reference :orders, :sales_channel, foreign_key: true, index: true
  end
end

