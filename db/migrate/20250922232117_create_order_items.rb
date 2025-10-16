# Enterprise-Grade Order Items Migration - Hyperscale Order Fulfillment Architecture
# Implements: Advanced inventory reconciliation, price protection, multi-seller orders
class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    # Enable advanced PostgreSQL extensions for enterprise order fulfillment
    enable_extension 'pg_stat_statements' unless extension_enabled?('pg_stat_statements')
    enable_extension 'pg_buffercache' unless extension_enabled?('pg_buffercache')
    enable_extension 'pg_prewarm' unless extension_enabled?('pg_prewarm')
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Core order_items table with enterprise-grade e-commerce architecture
    create_table :order_items, id: :uuid, default: -> { 'uuid_generate_v4()' } do |t|
      # Core associations and order relationship
      t.uuid :order_id, null: false, comment: 'Parent order for this item'
      t.uuid :product_id, null: false, comment: 'Product being ordered'
      t.uuid :line_item_id, comment: 'Source line item from cart conversion'
      t.uuid :seller_id, null: false, comment: 'Seller fulfilling this item'

      # Multi-tenancy and marketplace structure
      t.uuid :tenant_id, comment: 'Multi-tenant isolation for marketplace'
      t.string :fulfillment_model, default: 'direct', limit: 20, comment: 'Fulfillment model: direct, dropship, marketplace'

      # Product variant and customization tracking
      t.jsonb :selected_options, default: {}, comment: 'Selected product variants (size, color, etc.)'
      t.string :variant_sku, limit: 100, comment: 'SKU of fulfilled variant'
      t.text :customization_data, comment: 'Custom product modifications'

      # Pricing with price protection and reconciliation
      t.decimal :unit_price, precision: 15, scale: 4, null: false, comment: 'Price per unit at time of order'
      t.decimal :original_unit_price, precision: 15, scale: 4, comment: 'Original price for price protection'
      t.decimal :compare_at_price, precision: 15, scale: 4, comment: 'MSRP for discount calculations'
      t.decimal :line_total, precision: 15, scale: 4, null: false, comment: 'Total price (unit_price * quantity)'

      # Currency and regional pricing
      t.string :currency, default: 'USD', limit: 3, null: false, comment: 'ISO 4217 currency code'
      t.decimal :exchange_rate, precision: 15, scale: 8, comment: 'Exchange rate at time of order'

      # Quantity and inventory management
      t.integer :quantity, null: false, default: 1, comment: 'Quantity ordered'
      t.integer :fulfilled_quantity, default: 0, comment: 'Quantity already fulfilled'
      t.integer :cancelled_quantity, default: 0, comment: 'Quantity cancelled'
      t.integer :returned_quantity, default: 0, comment: 'Quantity returned'

      # Advanced order item features for enterprise e-commerce
      t.jsonb :applied_discounts, default: [], comment: 'Item-specific discounts and promotions'
      t.jsonb :tax_lines, default: [], comment: 'Item-specific tax calculations'
      t.decimal :tax_amount, precision: 15, scale: 4, default: 0.0, comment: 'Tax for this item'
      t.decimal :shipping_amount, precision: 15, scale: 4, default: 0.0, comment: 'Shipping allocated to this item'

      # Product snapshot for historical accuracy
      t.string :product_name_snapshot, limit: 200, comment: 'Product name at time of order'
      t.text :product_description_snapshot, comment: 'Product description for records'
      t.jsonb :product_image_snapshot, default: {}, comment: 'Product image for order records'

      # Fulfillment and logistics tracking
      t.integer :fulfillment_status, default: 0, null: false, comment: 'Item fulfillment progress'
      t.uuid :fulfillment_order_id, comment: 'External fulfillment system identifier'
      t.datetime :fulfillment_started_at, comment: 'Fulfillment process start timestamp'
      t.datetime :expected_delivery_at, comment: 'Expected delivery date'
      t.datetime :actual_delivery_at, comment: 'Actual delivery confirmation'

      # Inventory reconciliation and allocation
      t.bigint :inventory_reserved_at_order, comment: 'Inventory level when order was placed'
      t.datetime :inventory_allocated_at, comment: 'Inventory allocation timestamp'
      t.jsonb :inventory_allocations, default: [], comment: 'Detailed inventory allocation records'

      # Advanced item features
      t.boolean :requires_shipping, default: true, comment: 'Whether this item needs shipping'
      t.decimal :weight, precision: 10, scale: 3, comment: 'Item weight for shipping'
      t.jsonb :dimensions, comment: 'Item dimensions for shipping calculations'
      t.boolean :is_digital, default: false, comment: 'Digital vs physical item'

      # Digital product handling
      t.text :download_url, comment: 'Download URL for digital items'
      t.datetime :download_expires_at, comment: 'Download expiration'
      t.integer :download_count, default: 0, comment: 'Number of downloads'

      # Advanced tracking and quality control
      t.string :batch_number, limit: 50, comment: 'Manufacturing batch for quality tracking'
      t.datetime :manufactured_at, comment: 'Manufacturing date for expiration tracking'
      t.datetime :expires_at, comment: 'Product expiration date'

      # Return and refund management
      t.datetime :returned_at, comment: 'Return initiation timestamp'
      t.string :return_reason, limit: 100, comment: 'Reason for return'
      t.integer :return_quantity, default: 0, comment: 'Quantity returned'
      t.decimal :refund_amount, precision: 15, scale: 4, default: 0.0, comment: 'Refund amount for this item'

      # Advanced business logic
      t.decimal :commission_amount, precision: 15, scale: 4, default: 0.0, comment: 'Commission for marketplace'
      t.decimal :seller_payout_amount, precision: 15, scale: 4, default: 0.0, comment: 'Amount payable to seller'
      t.datetime :seller_paid_at, comment: 'Seller payment timestamp'

      # Quality and issue tracking
      t.jsonb :quality_issues, default: [], comment: 'Quality control issues identified'
      t.integer :quality_score, default: 100, comment: 'Quality score 0-100'
      t.datetime :quality_checked_at, comment: 'Last quality check timestamp'

      # Advanced item status and workflow
      t.integer :status, default: 0, null: false, comment: 'Order item lifecycle status'
      t.uuid :assigned_to_id, comment: 'User assigned for item processing'
      t.integer :priority, default: 0, comment: 'Processing priority for this item'

      # Cancellation and modification tracking
      t.datetime :cancelled_at, comment: 'Item cancellation timestamp'
      t.string :cancellation_reason, limit: 100, comment: 'Reason for item cancellation'
      t.uuid :cancelled_by_id, comment: 'User who cancelled this item'

      # Audit trail and compliance
      t.uuid :created_by_id, comment: 'User ID who created this order item'
      t.uuid :updated_by_id, comment: 'User ID who last updated this order item'
      t.datetime :approved_at, comment: 'Approval timestamp for high-value items'
      t.uuid :approved_by_id, comment: 'User who approved this item'

      # Performance optimization and analytics
      t.datetime :calculated_at, comment: 'Last price calculation timestamp'
      t.integer :calculation_version, default: 0, comment: 'Price calculation version'
      t.bigint :view_count, default: 0, comment: 'Item view count in order history'

      # Soft delete for data retention compliance
      t.datetime :deleted_at, index: true, comment: 'Soft delete with performance indexing'

      # Hyperscale performance timestamps
      t.datetime :created_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.datetime :updated_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false

      # Performance optimization columns
      t.tsvector :search_vector, comment: 'Full-text search vector for order item search'
    end

    # Enterprise-grade performance indexes for hyperscale order fulfillment
    # Composite indexes for complex order item query patterns
    add_index :order_items, [:order_id, :fulfillment_status, :status], comment: 'Order fulfillment progress tracking'
    add_index :order_items, [:product_id, :order_id, :status], comment: 'Product order history and inventory reconciliation'
    add_index :order_items, [:seller_id, :fulfillment_status, :order_id], order: { order_id: :desc }, comment: 'Seller fulfillment dashboard'
    add_index :order_items, [:tenant_id, :status, :order_id], order: { order_id: :desc }, comment: 'Multi-tenant order item management'
    add_index :order_items, [:line_item_id, :order_id], comment: 'Cart-to-order conversion tracking'
    add_index :order_items, [:fulfillment_order_id], where: 'fulfillment_order_id IS NOT NULL', comment: 'External fulfillment system integration'
    add_index :order_items, [:requires_shipping, :fulfillment_status], comment: 'Shipping vs digital item processing'
    add_index :order_items, [:is_digital, :download_expires_at], comment: 'Digital product expiry management'

    # Advanced search and analytics indexes
    add_index :order_items, :search_vector, using: :gin, comment: 'Full-text order item search'
    add_index :order_items, :selected_options, using: :gin, comment: 'Variant-based filtering and reporting'
    add_index :order_items, :applied_discounts, using: :gin, comment: 'Discount analysis for items'
    add_index :order_items, :tax_lines, using: :gin, comment: 'Tax compliance reporting'
    add_index :order_items, :inventory_allocations, using: :gin, comment: 'Inventory allocation tracking'

    # Temporal and lifecycle indexes
    add_index :order_items, [:created_at, :status], order: { created_at: :desc }, comment: 'Order item creation trends'
    add_index :order_items, [:fulfillment_started_at, :expected_delivery_at], comment: 'Fulfillment timeline tracking'
    add_index :order_items, [:returned_at, :return_reason], comment: 'Return analysis and prevention'
    add_index :order_items, [:cancelled_at, :cancellation_reason], comment: 'Cancellation tracking and analytics'

    # Performance and quality indexes
    add_index :order_items, [:quality_score, :status], comment: 'Quality-based item filtering'
    add_index :order_items, [:commission_amount, :seller_payout_amount], comment: 'Financial reconciliation queries'
    add_index :order_items, [:unit_price, :quantity], comment: 'Price and quantity analytics'

    # Partial indexes for performance optimization
    add_index :order_items, [:returned_at], where: 'returned_at IS NOT NULL', comment: 'Returned item processing'
    add_index :order_items, [:cancelled_at], where: 'cancelled_at IS NOT NULL', comment: 'Cancelled item management'
    add_index :order_items, [:approved_at], where: 'approved_at IS NOT NULL', comment: 'Approved item processing'

    # Foreign key constraints with cascade behavior
    add_foreign_key :order_items, :orders, column: :order_id, on_delete: :cascade
    add_foreign_key :order_items, :products, column: :product_id, on_delete: :cascade
    add_foreign_key :order_items, :users, column: :seller_id, on_delete: :cascade
    add_foreign_key :order_items, :users, column: :assigned_to_id, on_delete: :set_null
    add_foreign_key :order_items, :users, column: :created_by_id, on_delete: :set_null
    add_foreign_key :order_items, :users, column: :updated_by_id, on_delete: :set_null
    add_foreign_key :order_items, :users, column: :approved_by_id, on_delete: :set_null
    add_foreign_key :order_items, :users, column: :cancelled_by_id, on_delete: :set_null

    # Sophisticated check constraints for data integrity
    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_quantity_check
      CHECK (quantity > 0 AND fulfilled_quantity >= 0 AND cancelled_quantity >= 0 AND returned_quantity >= 0)
    SQL

    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_fulfillment_quantity_check
      CHECK (
        fulfilled_quantity + cancelled_quantity + returned_quantity <= quantity AND
        fulfilled_quantity >= 0 AND cancelled_quantity >= 0 AND returned_quantity >= 0
      )
    SQL

    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_prices_check
      CHECK (unit_price >= 0 AND line_total >= 0 AND tax_amount >= 0 AND shipping_amount >= 0)
    SQL

    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_status_check
      CHECK (status IN (0, 1, 2, 3, 4, 5, 6, 7, 8))
    SQL

    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_fulfillment_status_check
      CHECK (fulfillment_status IN (0, 1, 2, 3, 4, 5, 6))
    SQL

    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_currency_check
      CHECK (length(currency) = 3 AND currency ~ '^[A-Z]+$')
    SQL

    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_quality_score_check
      CHECK (quality_score >= 0 AND quality_score <= 100)
    SQL

    # Advanced constraint for temporal consistency
    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_temporal_consistency_check
      CHECK (updated_at >= created_at)
    SQL

    # Price calculation consistency constraint
    execute <<-SQL
      ALTER TABLE order_items ADD CONSTRAINT order_items_price_calculation_check
      CHECK (line_total = (unit_price * quantity))
    SQL

    # Order item audit triggers for comprehensive tracking
    execute <<-SQL
      CREATE OR REPLACE FUNCTION audit_order_items_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP(6);

        -- Build search vector for full-text search
        NEW.search_vector = to_tsvector('english',
          COALESCE(NEW.product_name_snapshot, '') || ' ' ||
          COALESCE(NEW.product_description_snapshot, '') || ' ' ||
          COALESCE(NEW.variant_sku, '') || ' ' ||
          COALESCE(NEW.batch_number, '') || ' ' ||
          COALESCE(NEW.customization_data, '')
        );

        IF TG_OP = 'INSERT' THEN
          NEW.created_at = CURRENT_TIMESTAMP(6);
          RETURN NEW;
        ELSIF TG_OP = 'UPDATE' THEN
          -- Update calculated fields when prices or quantities change
          IF OLD.unit_price != NEW.unit_price OR OLD.quantity != NEW.quantity THEN
            NEW.calculated_at = CURRENT_TIMESTAMP(6);
            NEW.calculation_version = NEW.calculation_version + 1;
            NEW.line_total = NEW.unit_price * NEW.quantity;
          END IF;
          RETURN NEW;
        END IF;
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply audit trigger
    execute <<-SQL
      CREATE TRIGGER order_items_audit_trigger
        BEFORE INSERT OR UPDATE ON order_items
        FOR EACH ROW EXECUTE FUNCTION audit_order_items_trigger()
    SQL

    # Performance monitoring for order item operations
    create_table :order_item_performance_metrics, id: false do |t|
      t.uuid :order_item_id, null: false
      t.string :operation_type, null: false, limit: 50
      t.decimal :processing_time_ms, precision: 8, scale: 3
      t.integer :quantity_processed
      t.decimal :amount_processed, precision: 15, scale: 4
      t.datetime :executed_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.foreign_key :order_items, column: :order_item_id, on_delete: :cascade
    end

    add_index :order_item_performance_metrics, [:order_item_id, :executed_at], order: { executed_at: :desc }
    add_index :order_item_performance_metrics, [:operation_type, :processing_time_ms], where: 'processing_time_ms > 100'
  end
end
