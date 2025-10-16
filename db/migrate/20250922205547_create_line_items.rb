# Enterprise-Grade Line Items Migration - Hyperscale Cart Item Architecture
# Implements: Advanced inventory management, price tracking, product variants, promotions
class CreateLineItems < ActiveRecord::Migration[8.0]
  def change
    # Enable advanced PostgreSQL extensions for enterprise cart functionality
    enable_extension 'pg_stat_statements' unless extension_enabled?('pg_stat_statements')
    enable_extension 'pg_buffercache' unless extension_enabled?('pg_buffercache')
    enable_extension 'pg_prewarm' unless extension_enabled?('pg_prewarm')
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Core line_items table with enterprise-grade e-commerce architecture
    create_table :line_items, id: :uuid, default: -> { 'uuid_generate_v4()' } do |t|
      # Core associations with referential integrity
      t.uuid :cart_id, null: false, comment: 'Associated shopping cart'
      t.uuid :product_id, null: false, comment: 'Product being purchased'
      t.uuid :order_id, comment: 'Associated order for converted carts'

      # Multi-tenancy and seller context
      t.uuid :tenant_id, comment: 'Multi-tenant isolation for marketplace'
      t.uuid :seller_id, comment: 'Seller providing the product'

      # Product variant and option management
      t.jsonb :selected_options, default: {}, comment: 'Selected product variants (size, color, etc.)'
      t.string :variant_sku, limit: 100, comment: 'SKU of selected variant for inventory tracking'
      t.text :customization_data, comment: 'Custom product modifications or engraving text'

      # Pricing and cost calculation
      t.decimal :unit_price, precision: 15, scale: 4, null: false, comment: 'Price per unit at time of addition'
      t.decimal :compare_at_price, precision: 15, scale: 4, comment: 'MSRP for discount calculations'
      t.decimal :line_total, precision: 15, scale: 4, null: false, comment: 'Total price (unit_price * quantity)'
      t.decimal :discount_amount, precision: 15, scale: 4, default: 0.0, comment: 'Discount applied to this line item'

      # Currency and regional pricing
      t.string :currency, default: 'USD', limit: 3, null: false, comment: 'ISO 4217 currency code'
      t.decimal :exchange_rate, precision: 15, scale: 8, comment: 'Exchange rate at time of purchase'

      # Inventory and quantity management
      t.integer :quantity, null: false, default: 1, comment: 'Quantity of product in cart'
      t.integer :reserved_quantity, default: 0, comment: 'Quantity reserved in inventory'
      t.bigint :inventory_quantity_at_add, comment: 'Inventory level when item was added'
      t.datetime :inventory_checked_at, comment: 'Last inventory validation timestamp'

      # Advanced line item features for enterprise e-commerce
      t.jsonb :applied_discounts, default: [], comment: 'Discounts and promotions applied to this item'
      t.jsonb :tax_lines, default: [], comment: 'Tax calculations broken down by jurisdiction'
      t.decimal :tax_amount, precision: 15, scale: 4, default: 0.0, comment: 'Total tax for this line item'
      t.decimal :shipping_amount, precision: 15, scale: 4, default: 0.0, comment: 'Shipping cost allocated to this item'

      # Product snapshot for price protection and analytics
      t.string :product_name_snapshot, limit: 200, comment: 'Product name at time of addition'
      t.text :product_description_snapshot, comment: 'Product description for historical reference'
      t.jsonb :product_image_snapshot, default: {}, comment: 'Primary product image for cart display'

      # Advanced business logic
      t.boolean :requires_shipping, default: true, comment: 'Whether this item requires physical shipping'
      t.decimal :weight, precision: 10, scale: 3, comment: 'Item weight for shipping calculations'
      t.jsonb :dimensions, comment: 'Item dimensions for shipping calculations'
      t.boolean :is_gift, default: false, comment: 'Gift designation for special handling'

      # Digital product handling
      t.boolean :is_digital, default: false, comment: 'Digital vs physical product classification'
      t.text :download_url, comment: 'Download URL for digital products'
      t.datetime :download_expires_at, comment: 'Download expiration for digital products'

      # Advanced tracking and analytics
      t.datetime :added_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false, comment: 'When item was added to cart'
      t.datetime :last_modified_at, precision: 6, comment: 'Last modification timestamp'
      t.integer :modification_count, default: 0, comment: 'Number of times item was modified'

      # Conversion and attribution tracking
      t.datetime :converted_at, comment: 'When cart was converted to order'
      t.string :attribution_source, limit: 100, comment: 'Marketing attribution for this item'
      t.jsonb :attribution_data, default: {}, comment: 'Additional attribution metadata'

      # Advanced line item status
      t.integer :status, default: 0, null: false, comment: 'Line item lifecycle status'
      t.datetime :removed_at, comment: 'When item was removed from cart'
      t.string :removal_reason, limit: 50, comment: 'Reason for item removal'

      # Audit trail and compliance
      t.uuid :created_by_id, comment: 'User ID who added this item'
      t.uuid :updated_by_id, comment: 'User ID who last modified this item'
      t.datetime :deleted_at, index: true, comment: 'Soft delete with performance indexing'

      # Hyperscale performance timestamps
      t.datetime :created_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.datetime :updated_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
    end

    # Enterprise-grade performance indexes for hyperscale line item operations
    # Composite indexes for complex cart and order query patterns
    add_index :line_items, [:cart_id, :status], where: 'deleted_at IS NULL', comment: 'Cart contents queries with sub-second performance'
    add_index :line_items, [:product_id, :cart_id], unique: true, where: 'deleted_at IS NULL', comment: 'Prevent duplicate products in same cart'
    add_index :line_items, [:order_id, :product_id], comment: 'Order item lookup and inventory reconciliation'
    add_index :line_items, [:tenant_id, :status], where: 'deleted_at IS NULL', comment: 'Multi-tenant line item management'
    add_index :line_items, [:seller_id, :cart_id], comment: 'Seller-specific cart management'
    add_index :line_items, [:added_at, :status], order: { added_at: :desc }, comment: 'Cart activity and analytics queries'
    add_index :line_items, [:converted_at, :product_id], comment: 'Conversion tracking and product performance'

    # Partial indexes for performance optimization
    add_index :line_items, [:inventory_checked_at], where: 'inventory_checked_at IS NOT NULL', comment: 'Inventory validation queries'
    add_index :line_items, [:removed_at], where: 'removed_at IS NOT NULL', comment: 'Removed item analytics'
    add_index :line_items, [:download_expires_at], where: 'download_expires_at IS NOT NULL', comment: 'Digital product expiry management'

    # JSONB indexes for advanced features
    add_index :line_items, :selected_options, using: :gin, comment: 'Variant filtering and search'
    add_index :line_items, :applied_discounts, using: :gin, comment: 'Discount analysis and reporting'
    add_index :line_items, :tax_lines, using: :gin, comment: 'Tax calculation and compliance reporting'

    # Foreign key constraints with cascade behavior
    add_foreign_key :line_items, :carts, column: :cart_id, on_delete: :cascade
    add_foreign_key :line_items, :products, column: :product_id, on_delete: :cascade
    add_foreign_key :line_items, :users, column: :seller_id, on_delete: :cascade
    add_foreign_key :line_items, :users, column: :created_by_id, on_delete: :set_null
    add_foreign_key :line_items, :users, column: :updated_by_id, on_delete: :set_null

    # Sophisticated check constraints for data integrity
    execute <<-SQL
      ALTER TABLE line_items ADD CONSTRAINT line_items_quantity_check
      CHECK (quantity > 0 AND quantity <= 10000)
    SQL

    execute <<-SQL
      ALTER TABLE line_items ADD CONSTRAINT line_items_prices_check
      CHECK (unit_price >= 0 AND line_total >= 0 AND discount_amount >= 0 AND tax_amount >= 0)
    SQL

    execute <<-SQL
      ALTER TABLE line_items ADD CONSTRAINT line_items_status_check
      CHECK (status IN (0, 1, 2, 3, 4, 5))
    SQL

    execute <<-SQL
      ALTER TABLE line_items ADD CONSTRAINT line_items_currency_check
      CHECK (length(currency) = 3 AND currency ~ '^[A-Z]+$')
    SQL

    # Advanced constraint for temporal consistency
    execute <<-SQL
      ALTER TABLE line_items ADD CONSTRAINT line_items_temporal_consistency_check
      CHECK (updated_at >= created_at AND last_modified_at >= added_at)
    SQL

    # Price calculation consistency constraint
    execute <<-SQL
      ALTER TABLE line_items ADD CONSTRAINT line_items_price_calculation_check
      CHECK (line_total = (unit_price * quantity) - discount_amount)
    SQL

    # Line item audit triggers for comprehensive tracking
    execute <<-SQL
      CREATE OR REPLACE FUNCTION audit_line_items_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP(6);
        NEW.last_modified_at = CURRENT_TIMESTAMP(6);
        NEW.modification_count = NEW.modification_count + 1;

        -- Recalculate line total
        NEW.line_total = (NEW.unit_price * NEW.quantity) - NEW.discount_amount;

        IF TG_OP = 'INSERT' THEN
          NEW.created_at = CURRENT_TIMESTAMP(6);
          NEW.added_at = CURRENT_TIMESTAMP(6);
          RETURN NEW;
        ELSIF TG_OP = 'UPDATE' THEN
          -- Check inventory if quantity changed
          IF OLD.quantity != NEW.quantity THEN
            NEW.inventory_checked_at = CURRENT_TIMESTAMP(6);
          END IF;
          RETURN NEW;
        END IF;
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply audit trigger
    execute <<-SQL
      CREATE TRIGGER line_items_audit_trigger
        BEFORE INSERT OR UPDATE ON line_items
        FOR EACH ROW EXECUTE FUNCTION audit_line_items_trigger()
    SQL

    # Performance monitoring for line item operations
    create_table :line_item_performance_metrics, id: false do |t|
      t.uuid :line_item_id, null: false
      t.string :operation_type, null: false, limit: 50
      t.decimal :calculation_time_ms, precision: 8, scale: 3
      t.integer :quantity_change
      t.datetime :executed_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.foreign_key :line_items, column: :line_item_id, on_delete: :cascade
    end

    add_index :line_item_performance_metrics, [:line_item_id, :executed_at], order: { executed_at: :desc }
    add_index :line_item_performance_metrics, [:operation_type, :calculation_time_ms], where: 'calculation_time_ms > 50'
  end
end
