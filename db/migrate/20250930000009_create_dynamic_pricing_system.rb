class CreateDynamicPricingSystem < ActiveRecord::Migration[8.0]
  def change
    # Pricing Rules
    create_table :pricing_rules do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      
      t.string :name, null: false
      t.text :description
      t.integer :rule_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :priority, null: false, default: 1
      
      t.integer :min_price_cents
      t.integer :max_price_cents
      
      t.date :start_date
      t.date :end_date
      
      t.jsonb :config, default: {}
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :pricing_rules, [:product_id, :status]
    add_index :pricing_rules, [:rule_type, :status]
    add_index :pricing_rules, :priority
    add_index :pricing_rules, [:start_date, :end_date]
    add_index :pricing_rules, :config, using: :gin
    
    # Pricing Rule Conditions
    create_table :pricing_rule_conditions do |t|
      t.references :pricing_rule, null: false, foreign_key: true
      
      t.integer :condition_type, null: false
      t.integer :operator, null: false
      t.string :value, null: false
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :pricing_rule_conditions, [:pricing_rule_id, :condition_type]
    
    # Price Changes (History)
    create_table :price_changes do |t|
      t.references :product, null: false, foreign_key: true
      t.references :pricing_rule, null: true, foreign_key: true
      t.references :user, null: true, foreign_key: true
      
      t.integer :old_price_cents, null: false
      t.integer :new_price_cents, null: false
      
      t.string :reason
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :price_changes, [:product_id, :created_at]
    add_index :price_changes, :pricing_rule_id
    add_index :price_changes, :created_at
    add_index :price_changes, :metadata, using: :gin
    
    # Competitor Prices
    create_table :competitor_prices do |t|
      t.string :competitor_name, null: false
      t.string :product_identifier, null: false # SKU or similar
      
      t.integer :price_cents, null: false
      t.integer :previous_price_cents
      
      t.string :url
      t.boolean :in_stock, default: true
      t.boolean :active, default: true
      
      t.datetime :last_checked_at
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :competitor_prices, [:competitor_name, :product_identifier], unique: true, name: 'index_competitor_prices_unique'
    add_index :competitor_prices, :product_identifier
    add_index :competitor_prices, [:active, :last_checked_at]
    add_index :competitor_prices, :metadata, using: :gin
    
    # Price Experiments (A/B Testing for Pricing)
    create_table :price_experiments do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      
      t.string :name, null: false
      t.text :description
      t.integer :status, null: false, default: 0 # draft, active, paused, completed
      
      t.integer :control_price_cents, null: false
      t.integer :variant_price_cents, null: false
      
      t.integer :control_views, default: 0
      t.integer :control_conversions, default: 0
      t.integer :variant_views, default: 0
      t.integer :variant_conversions, default: 0
      
      t.datetime :started_at
      t.datetime :ended_at
      
      t.string :winner # 'control', 'variant', or null
      t.float :confidence_level
      
      t.jsonb :results, default: {}
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :price_experiments, [:product_id, :status]
    add_index :price_experiments, :status
    add_index :price_experiments, [:started_at, :ended_at]
    
    # Add columns to products table
    add_column :products, :cost_cents, :integer, default: 0
    add_column :products, :min_price_cents, :integer
    add_column :products, :max_price_cents, :integer
    add_column :products, :auto_pricing_enabled, :boolean, default: false
    add_column :products, :last_price_update_at, :datetime
    add_column :products, :price_optimization_score, :integer, default: 0
    
    add_index :products, :auto_pricing_enabled
    add_index :products, :last_price_update_at
    add_index :products, :price_optimization_score
  end
end

