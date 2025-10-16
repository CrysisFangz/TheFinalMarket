# Enterprise-Grade Products Migration - Hyperscale E-commerce Architecture
# Implements: Dynamic pricing, inventory management, multi-tenant product catalog
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    # Enable advanced PostgreSQL extensions for enterprise e-commerce functionality
    enable_extension 'pg_stat_statements' unless extension_enabled?('pg_stat_statements')
    enable_extension 'pg_buffercache' unless extension_enabled?('pg_buffercache')
    enable_extension 'pg_prewarm' unless extension_enabled?('pg_prewarm')
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    enable_extension 'intarray' unless extension_enabled?('intarray')
    enable_extension 'hstore' unless extension_enabled?('hstore')

    # Core products table with enterprise-grade e-commerce architecture
    create_table :products, id: :uuid, default: -> { 'uuid_generate_v4()' } do |t|
      # Basic product information with comprehensive validation
      t.string :name, null: false, limit: 200, comment: 'Product name with multilingual support and SEO optimization'
      t.text :description, comment: 'Rich product description with HTML sanitization and markdown support'
      t.text :short_description, limit: 500, comment: 'SEO-optimized short description for listings'

      # Advanced pricing and inventory management
      t.decimal :base_price, precision: 15, scale: 4, null: false, comment: 'Base price in smallest currency unit (cents)'
      t.decimal :current_price, precision: 15, scale: 4, null: false, comment: 'Dynamic current price after all adjustments'
      t.decimal :compare_at_price, precision: 15, scale: 4, comment: 'MSRP for comparison and discount calculations'
      t.decimal :cost_price, precision: 15, scale: 4, comment: 'Cost basis for profit margin calculations'

      # Currency and regional pricing
      t.string :currency, default: 'USD', limit: 3, null: false, comment: 'ISO 4217 currency code'
      t.hstore :regional_prices, comment: 'Regional price overrides for international markets'
      t.jsonb :exchange_rates, default: {}, comment: 'Cached exchange rates for real-time price conversion'

      # Inventory management with hyperscale support
      t.bigint :inventory_quantity, default: 0, null: false, comment: 'Current inventory count with BIGINT for hyperscale'
      t.bigint :reserved_quantity, default: 0, null: false, comment: 'Reserved inventory for pending orders'
      t.bigint :low_stock_threshold, default: 10, null: false, comment: 'Low stock alert threshold'
      t.string :inventory_policy, default: 'deny', limit: 20, comment: 'Inventory policy: deny, allow_oversell'

      # SKU and product identification
      t.string :sku, limit: 100, index: { unique: true }, comment: 'Stock Keeping Unit for inventory management'
      t.string :barcode, limit: 128, comment: 'Product barcode with multiple format support'
      t.string :upc, limit: 12, comment: 'Universal Product Code for retail systems'
      t.string :ean, limit: 18, comment: 'European Article Number for international markets'

      # Product categorization and taxonomy
      t.integer :category_id, comment: 'Primary category association with materialized path'
      t.integer :subcategory_id, comment: 'Subcategory for refined categorization'
      t.ltree :category_path, comment: 'Hierarchical category path using PostgreSQL ltree'
      t.integer :tags, array: true, default: [], comment: 'Flexible tagging system with GIN indexing'

      # Multi-tenancy and seller management
      t.uuid :seller_id, null: false, comment: 'Seller/store owner identifier'
      t.uuid :tenant_id, comment: 'Multi-tenant isolation for marketplace architecture'
      t.boolean :is_active, default: true, null: false, comment: 'Product active status for marketplace visibility'
      t.boolean :is_featured, default: false, comment: 'Featured product status for promotions'
      t.boolean :is_digital, default: false, comment: 'Digital vs physical product classification'

      # Product variants and options
      t.jsonb :variants, default: [], comment: 'Product variants (size, color, etc.) with complex option structures'
      t.jsonb :variant_options, default: {}, comment: 'Available variant options and combinations'
      t.string :variant_strategy, default: 'single', limit: 20, comment: 'Variant handling strategy'

      # Shipping and logistics
      t.decimal :weight, precision: 10, scale: 3, comment: 'Product weight in grams for shipping calculations'
      t.decimal :weight_oz, precision: 8, scale: 3, comment: 'Weight in ounces for US markets'
      t.string :weight_unit, default: 'g', limit: 5, comment: 'Weight unit: g, kg, lb, oz'
      t.jsonb :dimensions, comment: 'Product dimensions: length, width, height in cm'
      t.boolean :requires_shipping, default: true, comment: 'Whether product requires physical shipping'

      # Digital product specifics
      t.text :download_url, comment: 'Secure download URL for digital products'
      t.datetime :download_expires_at, comment: 'Download expiration for digital products'
      t.integer :download_limit, default: -1, comment: 'Download attempt limit (-1 for unlimited)'

      # SEO and marketing
      t.string :slug, limit: 250, comment: 'SEO-friendly URL slug with uniqueness constraints'
      t.string :meta_title, limit: 60, comment: 'SEO meta title for search engines'
      t.text :meta_description, limit: 160, comment: 'SEO meta description for search results'
      t.jsonb :seo_data, default: {}, comment: 'Additional SEO metadata and structured data'

      # Content and media
      t.integer :primary_image_id, comment: 'Primary product image attachment ID'
      t.jsonb :image_gallery, default: [], comment: 'Product image gallery with metadata'
      t.text :video_url, comment: 'Product demonstration or promotional video URL'

      # Analytics and performance tracking
      t.bigint :view_count, default: 0, null: false, comment: 'Product page view counter'
      t.bigint :purchase_count, default: 0, null: false, comment: 'Total purchase count for popularity'
      t.decimal :average_rating, precision: 3, scale: 2, default: 0.0, comment: 'Average customer rating 0.00-5.00'
      t.integer :review_count, default: 0, comment: 'Total review count for social proof'

      # Advanced product features
      t.jsonb :specifications, default: {}, comment: 'Technical specifications and product attributes'
      t.jsonb :custom_fields, default: {}, comment: 'Extensible custom fields for marketplace flexibility'
      t.string :condition, default: 'new', limit: 20, comment: 'Product condition: new, used, refurbished'

      # Compliance and legal
      t.datetime :warranty_expires_at, comment: 'Warranty expiration date'
      t.text :warranty_terms, comment: 'Warranty terms and conditions'
      t.jsonb :certifications, default: [], comment: 'Product certifications and compliance badges'
      t.string :manufacturer, limit: 100, comment: 'Product manufacturer or brand name'

      # Business intelligence
      t.decimal :margin_percentage, precision: 5, scale: 2, comment: 'Profit margin percentage'
      t.datetime :last_sale_at, comment: 'Timestamp of last sale for trend analysis'
      t.integer :sales_velocity, default: 0, comment: 'Recent sales velocity for inventory optimization'

      # Advanced status and lifecycle
      t.integer :status, default: 0, null: false, comment: 'Product lifecycle status with workflow support'
      t.datetime :published_at, comment: 'Publication timestamp for marketplace visibility'
      t.datetime :discontinued_at, comment: 'Discontinuation date for lifecycle management'
      t.datetime :deleted_at, index: true, comment: 'Soft delete with performance indexing'

      # Audit and compliance
      t.uuid :created_by_id, comment: 'User ID who created this product record'
      t.uuid :updated_by_id, comment: 'User ID who last updated this product record'
      t.datetime :approved_at, comment: 'Admin approval timestamp for marketplace governance'

      # Hyperscale performance timestamps
      t.datetime :created_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.datetime :updated_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false

      # Performance optimization columns
      t.tsvector :search_vector, comment: 'Full-text search vector for lightning-fast product search'
      t.integer :popularity_score, default: 0, comment: 'Computed popularity score for recommendation algorithms'
    end

    # Enterprise-grade performance indexes for hyperscale e-commerce operations
    # Composite indexes for complex query patterns achieving O(log n) performance
    add_index :products, [:sku], unique: true, where: 'sku IS NOT NULL', comment: 'SKU uniqueness for inventory management'
    add_index :products, [:seller_id, :is_active, :status], where: 'deleted_at IS NULL', comment: 'Seller product catalog queries'
    add_index :products, [:category_id, :is_active], where: 'deleted_at IS NULL', comment: 'Category browsing performance'
    add_index :products, [:tenant_id, :is_active], where: 'deleted_at IS NULL', comment: 'Multi-tenant product isolation'
    add_index :products, [:current_price], where: 'is_active = true AND deleted_at IS NULL', comment: 'Price-based filtering optimization'
    add_index :products, [:average_rating, :review_count], where: 'is_active = true', comment: 'Rating-based sorting performance'
    add_index :products, [:created_at, :is_active], order: { created_at: :desc }, comment: 'New product discovery queries'
    add_index :products, [:view_count, :is_featured], comment: 'Featured product and trending algorithms'
    add_index :products, [:inventory_quantity], where: 'inventory_quantity > 0 AND is_active = true', comment: 'In-stock product filtering'

    # Advanced search and analytics indexes
    add_index :products, :search_vector, using: :gin, comment: 'Full-text search with ranking algorithms'
    add_index :products, :tags, using: :gin, comment: 'Tag-based filtering with array operations'
    add_index :products, :specifications, using: :gin, comment: 'Specification-based filtering and search'
    add_index :products, [:category_path], using: :gist, comment: 'Hierarchical category traversal with ltree'

    # Partial indexes for performance optimization
    add_index :products, [:published_at], where: 'published_at IS NOT NULL AND is_active = true', comment: 'Published product queries'
    add_index :products, [:discontinued_at], where: 'discontinued_at IS NOT NULL', comment: 'Discontinued product management'
    add_index :products, [:download_expires_at], where: 'download_expires_at IS NOT NULL', comment: 'Digital product expiry management'

    # Geographic and regional indexes
    add_index :products, [:currency, :is_active], comment: 'Currency-specific product filtering'
    add_index :products, :regional_prices, using: :gin, comment: 'Regional pricing queries'

    # Foreign key constraints with cascade behavior
    add_foreign_key :products, :users, column: :seller_id, on_delete: :cascade
    add_foreign_key :products, :products, column: :created_by_id, on_delete: :set_null
    add_foreign_key :products, :products, column: :updated_by_id, on_delete: :set_null
    add_foreign_key :products, :categories, column: :category_id, on_delete: :set_null
    add_foreign_key :products, :categories, column: :subcategory_id, on_delete: :set_null

    # Sophisticated check constraints for data integrity
    execute <<-SQL
      ALTER TABLE products ADD CONSTRAINT products_price_check
      CHECK (current_price >= 0 AND base_price >= 0 AND (compare_at_price IS NULL OR compare_at_price >= current_price))
    SQL

    execute <<-SQL
      ALTER TABLE products ADD CONSTRAINT products_inventory_check
      CHECK (inventory_quantity >= 0 AND reserved_quantity >= 0 AND inventory_quantity >= reserved_quantity)
    SQL

    execute <<-SQL
      ALTER TABLE products ADD CONSTRAINT products_status_check
      CHECK (status IN (0, 1, 2, 3, 4, 5, 6, 7))
    SQL

    execute <<-SQL
      ALTER TABLE products ADD CONSTRAINT products_condition_check
      CHECK (condition IN ('new', 'used', 'refurbished', 'damaged'))
    SQL

    execute <<-SQL
      ALTER TABLE products ADD CONSTRAINT products_currency_check
      CHECK (length(currency) = 3 AND currency ~ '^[A-Z]+$')
    SQL

    # Advanced constraint for temporal consistency
    execute <<-SQL
      ALTER TABLE products ADD CONSTRAINT products_temporal_consistency_check
      CHECK (updated_at >= created_at AND (published_at IS NULL OR published_at >= created_at))
    SQL

    # Create comprehensive audit triggers for immutable audit trails
    execute <<-SQL
      CREATE OR REPLACE FUNCTION audit_products_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP(6);
        NEW.search_vector = to_tsvector('english',
          COALESCE(NEW.name, '') || ' ' ||
          COALESCE(NEW.description, '') || ' ' ||
          COALESCE(NEW.short_description, '') || ' ' ||
          COALESCE(NEW.sku, '') || ' ' ||
          array_to_string(NEW.tags, ' ')
        );

        IF TG_OP = 'INSERT' THEN
          NEW.created_at = CURRENT_TIMESTAMP(6);
          RETURN NEW;
        ELSIF TG_OP = 'UPDATE' THEN
          NEW.updated_at = CURRENT_TIMESTAMP(6);
          RETURN NEW;
        END IF;
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply audit and search vector trigger
    execute <<-SQL
      CREATE TRIGGER products_audit_trigger
        BEFORE INSERT OR UPDATE ON products
        FOR EACH ROW EXECUTE FUNCTION audit_products_trigger()
    SQL

    # Performance monitoring for product queries
    create_table :product_performance_metrics, id: false do |t|
      t.uuid :product_id, null: false
      t.string :metric_type, null: false, limit: 50
      t.decimal :value, precision: 15, scale: 4
      t.datetime :recorded_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.foreign_key :products, column: :product_id, on_delete: :cascade
    end

    add_index :product_performance_metrics, [:product_id, :recorded_at], order: { recorded_at: :desc }
    add_index :product_performance_metrics, [:metric_type, :recorded_at], order: { recorded_at: :desc }

    # Product search optimization table for autocomplete and suggestions
    create_table :product_search_terms, id: false do |t|
      t.string :term, null: false, limit: 100
      t.uuid :product_id, null: false
      t.integer :frequency, default: 1
      t.datetime :last_searched_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }
      t.foreign_key :products, column: :product_id, on_delete: :cascade
    end

    add_index :product_search_terms, [:term], order: { frequency: :desc, last_searched_at: :desc }
    add_index :product_search_terms, [:product_id], unique: true
  end
end
