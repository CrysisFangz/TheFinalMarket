class CreateAdvancedSellerTools < ActiveRecord::Migration[8.0]
  def change
    # Seller Analytics
    create_table :seller_analytics do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.date :date, null: false
      t.integer :total_sales_cents, default: 0
      t.integer :orders_count, default: 0
      t.integer :units_sold, default: 0
      t.integer :average_order_value_cents, default: 0
      t.decimal :conversion_rate, precision: 5, scale: 2, default: 0
      t.integer :page_views, default: 0
      t.integer :unique_visitors, default: 0
      t.integer :cart_additions, default: 0
      t.integer :revenue_per_visitor_cents, default: 0
      t.decimal :return_rate, precision: 5, scale: 2, default: 0
      t.decimal :customer_satisfaction_score, precision: 3, scale: 2, default: 0
      
      t.timestamps
      
      t.index [:seller_id, :date], unique: true
      t.index :date
    end
    
    # Marketing Campaigns
    create_table :marketing_campaigns do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.integer :campaign_type, null: false
      t.integer :status, default: 0
      t.text :subject_line
      t.text :email_content
      t.integer :budget_cents
      t.datetime :launched_at
      t.datetime :completed_at
      t.string :ab_test_variant
      t.integer :ab_test_parent_id
      t.jsonb :targeting_rules, default: {}
      
      t.timestamps
      
      t.index :campaign_type
      t.index :status
      t.index :ab_test_parent_id
    end
    
    # Campaign Emails
    create_table :campaign_emails do |t|
      t.references :marketing_campaign, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :subject
      t.text :content
      t.integer :status, default: 0
      t.datetime :scheduled_for
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.datetime :converted_at
      t.integer :revenue_generated_cents, default: 0
      
      t.timestamps
      
      t.index :status
      t.index :sent_at
      t.index :opened_at
    end
    
    # Campaign Analytics
    create_table :campaign_analytics do |t|
      t.references :marketing_campaign, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :emails_sent, default: 0
      t.integer :emails_delivered, default: 0
      t.integer :emails_opened, default: 0
      t.integer :emails_clicked, default: 0
      t.integer :conversions, default: 0
      t.integer :revenue_cents, default: 0
      
      t.timestamps
      
      t.index [:marketing_campaign_id, :date], unique: true
    end
    
    # Inventory Forecasts
    create_table :inventory_forecasts do |t|
      t.references :product, null: false, foreign_key: true
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.date :forecast_date, null: false
      t.integer :forecast_method, default: 0
      t.integer :predicted_demand, null: false
      t.decimal :confidence_level, precision: 5, scale: 2
      t.integer :current_stock
      t.integer :recommended_reorder
      t.string :stockout_risk
      
      t.timestamps
      
      t.index [:product_id, :forecast_date]
      t.index :forecast_date
      t.index :forecast_method
    end
    
    # Competitor Intelligence
    create_table :competitor_intelligences do |t|
      t.references :product, null: false, foreign_key: true
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.string :competitor_name, null: false
      t.integer :competitor_price_cents
      t.string :competitor_stock_status
      t.decimal :competitor_rating, precision: 3, scale: 2
      t.integer :competitor_reviews_count
      t.integer :competitor_shipping_cost_cents
      t.integer :competitor_delivery_days
      t.integer :data_source, default: 0
      t.string :competitor_url
      t.datetime :scraped_at
      t.decimal :price_difference_percentage, precision: 5, scale: 2
      
      t.timestamps
      
      t.index :competitor_name
      t.index :scraped_at
      t.index :data_source
    end
    
    # Product A/B Tests
    create_table :product_ab_tests do |t|
      t.references :product, null: false, foreign_key: true
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.string :test_name, null: false
      t.integer :test_type, null: false
      t.integer :status, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :winning_variant_id
      t.boolean :applied, default: false
      t.datetime :applied_at
      
      t.timestamps
      
      t.index :test_type
      t.index :status
      t.index :winning_variant_id
    end
    
    # A/B Test Variants
    create_table :ab_test_variants do |t|
      t.references :product_ab_test, null: false, foreign_key: true
      t.string :variant_name, null: false
      t.boolean :is_control, default: false
      t.jsonb :variant_data, default: {}
      
      t.timestamps
      
      t.index :is_control
    end
    
    # A/B Test Impressions
    create_table :ab_test_impressions do |t|
      t.references :product_ab_test, null: false, foreign_key: true
      t.references :ab_test_variant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :order, foreign_key: true
      t.datetime :viewed_at
      t.boolean :converted, default: false
      t.datetime :converted_at
      t.integer :revenue_cents, default: 0
      
      t.timestamps
      
      t.index :converted
      t.index :viewed_at
    end
    
    # Seller API Keys
    create_table :seller_api_keys do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :api_key, null: false
      t.string :api_secret
      t.boolean :active, default: true
      t.datetime :last_used_at
      t.datetime :expires_at
      t.jsonb :permissions, default: {}
      t.integer :rate_limit, default: 1000
      
      t.timestamps
      
      t.index :api_key, unique: true
      t.index :active
    end
    
    # API Request Logs
    create_table :api_request_logs do |t|
      t.references :seller_api_key, null: false, foreign_key: true
      t.string :endpoint
      t.string :method
      t.integer :status_code
      t.integer :response_time_ms
      t.string :ip_address
      t.datetime :requested_at
      
      t.timestamps
      
      t.index :endpoint
      t.index :requested_at
    end
    
    # Add seller columns to users
    add_column :users, :seller_tier, :integer, default: 0
    add_column :users, :seller_rating, :decimal, precision: 3, scale: 2
    add_column :users, :total_sales_cents, :integer, default: 0
    add_column :users, :total_orders, :integer, default: 0
    
    add_index :users, :seller_tier
    add_index :users, :seller_rating
  end
end

