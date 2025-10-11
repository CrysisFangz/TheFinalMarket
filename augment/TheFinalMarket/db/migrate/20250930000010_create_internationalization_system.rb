class CreateInternationalizationSystem < ActiveRecord::Migration[8.0]
  def change
    # Currencies
    create_table :currencies do |t|
      t.string :code, null: false, limit: 3
      t.string :name, null: false
      t.string :symbol, null: false
      t.string :symbol_position, default: 'before' # 'before' or 'after'
      
      t.integer :decimal_places, default: 2
      t.string :thousands_separator, default: ','
      t.string :decimal_separator, default: '.'
      
      t.boolean :active, default: true
      t.boolean :supported, default: true
      t.boolean :is_base, default: false
      
      t.integer :popularity_rank, default: 999
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :currencies, :code, unique: true
    add_index :currencies, [:active, :supported]
    add_index :currencies, :popularity_rank
    add_index :currencies, :is_base
    
    # Exchange Rates
    create_table :exchange_rates do |t|
      t.references :currency, null: false, foreign_key: true
      
      t.decimal :rate, precision: 20, scale: 10, null: false
      t.integer :source, default: 0 # enum
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :exchange_rates, [:currency_id, :created_at]
    add_index :exchange_rates, :created_at
    
    # Countries
    create_table :countries do |t|
      t.string :code, null: false, limit: 2
      t.string :name, null: false
      t.string :native_name
      
      t.string :currency_code, limit: 3
      t.string :locale_code
      t.string :timezone
      
      t.string :phone_code
      t.string :continent
      
      t.boolean :active, default: true
      t.boolean :supported_for_shipping, default: false
      t.boolean :requires_customs, default: false
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :countries, :code, unique: true
    add_index :countries, :currency_code
    add_index :countries, [:active, :supported_for_shipping]
    
    # Shipping Zones
    create_table :shipping_zones do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      
      t.boolean :active, default: true
      t.integer :priority, default: 999
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :shipping_zones, :code, unique: true
    add_index :shipping_zones, [:active, :priority]
    
    # Shipping Zone Countries (Join Table)
    create_table :shipping_zone_countries do |t|
      t.references :shipping_zone, null: false, foreign_key: true
      t.references :country, null: false, foreign_key: true
      
      t.timestamps
    end
    
    add_index :shipping_zone_countries, [:shipping_zone_id, :country_id], 
              unique: true, name: 'index_shipping_zone_countries_unique'
    
    # Shipping Rates
    create_table :shipping_rates do |t|
      t.references :shipping_zone, null: false, foreign_key: true
      
      t.integer :service_level, null: false, default: 1 # enum
      t.string :carrier_name
      
      t.integer :base_rate_cents, null: false, default: 0
      t.integer :per_kg_rate_cents
      t.integer :min_rate_cents
      t.integer :max_rate_cents
      
      t.integer :min_weight_grams, default: 0
      t.integer :max_weight_grams
      
      t.integer :min_delivery_days
      t.integer :max_delivery_days
      
      t.boolean :active, default: true
      t.boolean :requires_signature, default: false
      t.boolean :includes_tracking, default: true
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :shipping_rates, [:shipping_zone_id, :service_level]
    add_index :shipping_rates, :active
    
    # Tax Rates
    create_table :tax_rates do |t|
      t.references :country, null: false, foreign_key: true
      
      t.string :name, null: false
      t.string :tax_type # 'vat', 'gst', 'sales_tax', etc.
      t.decimal :rate, precision: 5, scale: 2, null: false # percentage
      
      t.string :product_category # optional, for category-specific rates
      
      t.boolean :active, default: true
      t.boolean :included_in_price, default: false
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :tax_rates, [:country_id, :product_category]
    add_index :tax_rates, :active
    
    # Content Translations
    create_table :content_translations do |t|
      t.references :translatable, polymorphic: true, null: false
      
      t.string :locale, null: false
      t.string :attribute, null: false
      t.text :value
      
      t.string :translator # 'manual', 'google', 'deepl', etc.
      t.boolean :verified, default: false
      
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :content_translations, [:translatable_type, :translatable_id, :locale, :attribute],
              name: 'index_content_translations_unique', unique: true
    add_index :content_translations, [:locale, :attribute]
    
    # User Currency Preferences
    create_table :user_currency_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      
      t.timestamps
    end
    
    add_index :user_currency_preferences, :user_id, unique: true
    
    # Add columns to users table
    add_column :users, :locale, :string, default: 'en'
    add_column :users, :timezone, :string, default: 'UTC'
    add_column :users, :country_code, :string, limit: 2
    
    add_index :users, :locale
    add_index :users, :country_code
    
    # Add columns to products table
    add_column :products, :weight_grams, :integer, default: 0
    add_column :products, :requires_shipping, :boolean, default: true
    add_column :products, :ships_internationally, :boolean, default: false
    add_column :products, :origin_country_code, :string, limit: 2
    
    add_index :products, :ships_internationally
    add_index :products, :origin_country_code
    
    # Add columns to orders table
    add_column :orders, :currency_code, :string, limit: 3
    add_column :orders, :exchange_rate, :decimal, precision: 20, scale: 10
    add_column :orders, :shipping_country_code, :string, limit: 2
    add_column :orders, :tax_amount_cents, :integer, default: 0
    add_column :orders, :shipping_cost_cents, :integer, default: 0
    
    add_index :orders, :currency_code
    add_index :orders, :shipping_country_code
  end
end

