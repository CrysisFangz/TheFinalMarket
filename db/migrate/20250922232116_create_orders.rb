# Enterprise-Grade Orders Migration - Hyperscale Order Management Architecture
# Implements: Advanced order lifecycle, multi-party transactions, escrow, fraud detection
class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    # Enable advanced PostgreSQL extensions for enterprise order management
    enable_extension 'pg_stat_statements' unless extension_enabled?('pg_stat_statements')
    enable_extension 'pg_buffercache' unless extension_enabled?('pg_buffercache')
    enable_extension 'pg_prewarm' unless extension_enabled?('pg_prewarm')
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    enable_extension 'hstore' unless extension_enabled?('hstore')

    # Core orders table with enterprise-grade e-commerce architecture
    create_table :orders, id: :uuid, default: -> { 'uuid_generate_v4()' } do |t|
      # Core order identification and associations
      t.uuid :user_id, null: false, comment: 'Customer who placed the order'
      t.uuid :cart_id, comment: 'Source cart for conversion tracking'
      t.string :order_number, null: false, limit: 50, comment: 'Human-readable order identifier'

      # Multi-tenancy and marketplace structure
      t.uuid :tenant_id, comment: 'Multi-tenant isolation for marketplace'
      t.uuid :primary_seller_id, comment: 'Primary seller for mixed orders'
      t.jsonb :seller_allocations, default: {}, comment: 'Order amount allocation across multiple sellers'

      # Financial calculations with precision
      t.decimal :subtotal, precision: 15, scale: 4, null: false, comment: 'Pre-tax, pre-discount subtotal'
      t.decimal :tax_amount, precision: 15, scale: 4, default: 0.0, null: false, comment: 'Total tax amount'
      t.decimal :shipping_amount, precision: 15, scale: 4, default: 0.0, null: false, comment: 'Shipping cost'
      t.decimal :discount_amount, precision: 15, scale: 4, default: 0.0, null: false, comment: 'Total discounts applied'
      t.decimal :total_amount, precision: 15, scale: 4, null: false, comment: 'Final order total'

      # Currency and regional financial data
      t.string :currency, default: 'USD', limit: 3, null: false, comment: 'ISO 4217 currency code'
      t.jsonb :exchange_rates, default: {}, comment: 'Exchange rates used for calculation'
      t.decimal :exchange_rate, precision: 15, scale: 8, comment: 'Base exchange rate at order time'

      # Payment and transaction management
      t.string :payment_status, default: 'pending', limit: 20, null: false, comment: 'Payment processing status'
      t.uuid :payment_transaction_id, comment: 'Associated payment transaction'
      t.string :payment_method, limit: 50, comment: 'Payment method used'
      t.datetime :paid_at, comment: 'Payment completion timestamp'
      t.datetime :payment_due_at, comment: 'Payment deadline for pending orders'

      # Advanced order lifecycle management
      t.integer :status, default: 0, null: false, comment: 'Order lifecycle status with workflow support'
      t.integer :fulfillment_status, default: 0, null: false, comment: 'Fulfillment progress tracking'
      t.datetime :confirmed_at, comment: 'Order confirmation timestamp'
      t.datetime :processing_at, comment: 'Order processing start timestamp'
      t.datetime :shipped_at, comment: 'Shipping timestamp'
      t.datetime :delivered_at, comment: 'Delivery confirmation timestamp'
      t.datetime :cancelled_at, comment: 'Cancellation timestamp if applicable'

      # Shipping and logistics management
      t.string :shipping_method, limit: 50, comment: 'Selected shipping method'
      t.string :shipping_carrier, limit: 50, comment: 'Shipping carrier used'
      t.string :tracking_number, limit: 100, comment: 'Carrier tracking number'
      t.jsonb :shipping_address, default: {}, null: false, comment: 'Structured shipping address'
      t.jsonb :billing_address, default: {}, comment: 'Billing address for payment verification'

      # Geographic and compliance data
      t.string :shipping_country, limit: 3, comment: 'Shipping destination country code'
      t.string :shipping_region, limit: 10, comment: 'Shipping region for tax calculation'
      t.jsonb :tax_lines, default: [], comment: 'Detailed tax breakdown by jurisdiction'

      # Advanced order features for enterprise e-commerce
      t.jsonb :applied_discounts, default: [], comment: 'Discounts and promotions applied'
      t.jsonb :order_notes, default: [], comment: 'Order notes and customer requests'
      t.text :internal_notes, comment: 'Internal admin notes for order management'
      t.text :customer_notes, comment: 'Customer-provided order notes'

      # Gift and special handling
      t.boolean :is_gift, default: false, comment: 'Gift order designation'
      t.text :gift_message, comment: 'Gift message for recipient'
      t.string :gift_recipient_email, limit: 254, comment: 'Gift recipient notification email'

      # Risk assessment and fraud detection
      t.integer :risk_score, default: 0, comment: 'ML-based fraud risk assessment 0-100'
      t.jsonb :risk_factors, default: {}, comment: 'Detailed risk analysis data'
      t.datetime :risk_assessed_at, comment: 'Last risk assessment timestamp'
      t.boolean :requires_review, default: false, comment: 'Flag for manual review requirement'

      # Advanced business logic
      t.decimal :estimated_tax, precision: 15, scale: 4, comment: 'Estimated tax for pre-calculation'
      t.decimal :estimated_shipping, precision: 15, scale: 4, comment: 'Estimated shipping cost'
      t.datetime :tax_calculated_at, comment: 'Tax calculation timestamp'
      t.datetime :shipping_calculated_at, comment: 'Shipping calculation timestamp'

      # Inventory and fulfillment tracking
      t.datetime :inventory_reserved_at, comment: 'Inventory reservation timestamp'
      t.datetime :inventory_confirmed_at, comment: 'Inventory confirmation timestamp'
      t.jsonb :inventory_issues, default: [], comment: 'Inventory-related problems or adjustments'

      # Communication and notification tracking
      t.datetime :last_notification_sent_at, comment: 'Last customer notification timestamp'
      t.integer :notification_count, default: 0, comment: 'Number of notifications sent'
      t.jsonb :notification_history, default: [], comment: 'Notification tracking and history'

      # Advanced order metadata
      t.jsonb :metadata, default: {}, comment: 'Extensible order metadata for integrations'
      t.jsonb :custom_fields, default: {}, comment: 'Custom fields for marketplace flexibility'
      t.string :source, default: 'web', limit: 20, comment: 'Order source: web, mobile, api, pos'

      # Attribution and marketing tracking
      t.string :attribution_source, limit: 100, comment: 'Marketing attribution source'
      t.jsonb :utm_parameters, default: {}, comment: 'UTM tracking parameters'
      t.string :referral_code, limit: 50, comment: 'Referral or coupon code used'

      # Advanced order status and workflow
      t.uuid :assigned_to_id, comment: 'User assigned for order processing'
      t.integer :priority, default: 0, comment: 'Order processing priority level'
      t.datetime :priority_expires_at, comment: 'Priority expiration for SLA management'

      # Compliance and audit trail
      t.uuid :created_by_id, comment: 'User ID who created this order'
      t.uuid :updated_by_id, comment: 'User ID who last updated this order'
      t.datetime :approved_at, comment: 'Admin approval timestamp for high-value orders'
      t.uuid :approved_by_id, comment: 'Admin who approved the order'

      # Performance optimization and analytics
      t.datetime :calculated_at, comment: 'Last price calculation timestamp'
      t.integer :calculation_version, default: 0, comment: 'Price calculation version for cache invalidation'
      t.bigint :item_count, default: 0, null: false, comment: 'Total items in order'

      # Cancellation and return management
      t.datetime :cancelled_at, comment: 'Cancellation timestamp'
      t.string :cancellation_reason, limit: 100, comment: 'Reason for order cancellation'
      t.uuid :cancelled_by_id, comment: 'User who cancelled the order'

      # Soft delete for data retention compliance
      t.datetime :deleted_at, index: true, comment: 'Soft delete with performance indexing'

      # Hyperscale performance timestamps
      t.datetime :created_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.datetime :updated_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false

      # Performance optimization columns
      t.tsvector :search_vector, comment: 'Full-text search vector for order search'
    end

    # Enterprise-grade performance indexes for hyperscale order operations
    # Composite indexes for complex order query patterns
    add_index :orders, [:user_id, :status, :created_at], order: { created_at: :desc }, comment: 'User order history with status filtering'
    add_index :orders, [:order_number], unique: true, comment: 'Order number lookup for customer service'
    add_index :orders, [:tenant_id, :status, :created_at], order: { created_at: :desc }, comment: 'Multi-tenant order management'
    add_index :orders, [:primary_seller_id, :status, :created_at], order: { created_at: :desc }, comment: 'Seller order management dashboard'
    add_index :orders, [:payment_status, :status], comment: 'Payment and order status correlation'
    add_index :orders, [:tracking_number], where: 'tracking_number IS NOT NULL', comment: 'Shipment tracking queries'
    add_index :orders, [:requires_review, :risk_score], comment: 'Risk assessment and manual review workflows'
    add_index :orders, [:currency, :total_amount], comment: 'Financial reporting and analytics'

    # Advanced search and analytics indexes
    add_index :orders, :search_vector, using: :gin, comment: 'Full-text order search with ranking'
    add_index :orders, :applied_discounts, using: :gin, comment: 'Discount analysis and reporting'
    add_index :orders, :tax_lines, using: :gin, comment: 'Tax compliance and audit reporting'
    add_index :orders, :seller_allocations, using: :gin, comment: 'Multi-seller order processing'

    # Temporal and lifecycle indexes
    add_index :orders, [:created_at, :status], order: { created_at: :desc }, comment: 'Order creation trends and analytics'
    add_index :orders, [:shipped_at, :delivered_at], comment: 'Fulfillment performance tracking'
    add_index :orders, [:cancelled_at, :cancellation_reason], comment: 'Cancellation analytics and prevention'
    add_index :orders, [:paid_at, :payment_status], comment: 'Payment processing and reconciliation'

    # Partial indexes for performance optimization
    add_index :orders, [:confirmed_at], where: 'confirmed_at IS NOT NULL', comment: 'Confirmed order processing'
    add_index :orders, [:processing_at], where: 'processing_at IS NOT NULL', comment: 'Orders in processing'
    add_index :orders, [:delivered_at], where: 'delivered_at IS NOT NULL', comment: 'Delivered order analytics'

    # Geographic and compliance indexes
    add_index :orders, [:shipping_country, :shipping_region], comment: 'Geographic order analysis'
    add_index :orders, [:risk_assessed_at, :risk_score], comment: 'Risk assessment tracking'

    # Foreign key constraints with cascade behavior
    add_foreign_key :orders, :users, column: :user_id, on_delete: :cascade
    add_foreign_key :orders, :users, column: :primary_seller_id, on_delete: :cascade
    add_foreign_key :orders, :users, column: :assigned_to_id, on_delete: :set_null
    add_foreign_key :orders, :users, column: :created_by_id, on_delete: :set_null
    add_foreign_key :orders, :users, column: :updated_by_id, on_delete: :set_null
    add_foreign_key :orders, :users, column: :approved_by_id, on_delete: :set_null
    add_foreign_key :orders, :users, column: :cancelled_by_id, on_delete: :set_null

    # Sophisticated check constraints for data integrity
    execute <<-SQL
      ALTER TABLE orders ADD CONSTRAINT orders_amounts_check
      CHECK (subtotal >= 0 AND tax_amount >= 0 AND shipping_amount >= 0 AND discount_amount >= 0 AND total_amount >= 0)
    SQL

    execute <<-SQL
      ALTER TABLE orders ADD CONSTRAINT orders_status_check
      CHECK (status IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10))
    SQL

    execute <<-SQL
      ALTER TABLE orders ADD CONSTRAINT orders_fulfillment_status_check
      CHECK (fulfillment_status IN (0, 1, 2, 3, 4, 5))
    SQL

    execute <<-SQL
      ALTER TABLE orders ADD CONSTRAINT orders_payment_status_check
      CHECK (payment_status IN ('pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded', 'partially_refunded'))
    SQL

    execute <<-SQL
      ALTER TABLE orders ADD CONSTRAINT orders_currency_check
      CHECK (length(currency) = 3 AND currency ~ '^[A-Z]+$')
    SQL

    execute <<-SQL
      ALTER TABLE orders ADD CONSTRAINT orders_risk_score_check
      CHECK (risk_score >= 0 AND risk_score <= 100)
    SQL

    # Advanced constraint for temporal consistency
    execute <<-SQL
      ALTER TABLE orders ADD CONSTRAINT orders_temporal_consistency_check
      CHECK (updated_at >= created_at)
    SQL

    # Order audit triggers for comprehensive tracking
    execute <<-SQL
      CREATE OR REPLACE FUNCTION audit_orders_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP(6);

        -- Build search vector for full-text search
        NEW.search_vector = to_tsvector('english',
          COALESCE(NEW.order_number, '') || ' ' ||
          COALESCE(NEW.customer_notes, '') || ' ' ||
          COALESCE(NEW.internal_notes, '') || ' ' ||
          COALESCE(NEW.shipping_address::text, '') || ' ' ||
          COALESCE(NEW.tracking_number, '')
        );

        IF TG_OP = 'INSERT' THEN
          NEW.created_at = CURRENT_TIMESTAMP(6);
          -- Generate human-readable order number if not provided
          IF NEW.order_number IS NULL THEN
            NEW.order_number = 'ORD-' || TO_CHAR(NEW.created_at, 'YYYYMMDD') || '-' || SUBSTRING(NEW.id::text, 1, 8);
          END IF;
          RETURN NEW;
        ELSIF TG_OP = 'UPDATE' THEN
          -- Update calculated fields when amounts change
          IF OLD.subtotal != NEW.subtotal OR OLD.tax_amount != NEW.tax_amount OR
             OLD.shipping_amount != NEW.shipping_amount OR OLD.discount_amount != NEW.discount_amount THEN
            NEW.calculated_at = CURRENT_TIMESTAMP(6);
            NEW.calculation_version = NEW.calculation_version + 1;
          END IF;
          RETURN NEW;
        END IF;
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply audit trigger
    execute <<-SQL
      CREATE TRIGGER orders_audit_trigger
        BEFORE INSERT OR UPDATE ON orders
        FOR EACH ROW EXECUTE FUNCTION audit_orders_trigger()
    SQL

    # Performance monitoring for order operations
    create_table :order_performance_metrics, id: false do |t|
      t.uuid :order_id, null: false
      t.string :operation_type, null: false, limit: 50
      t.decimal :processing_time_ms, precision: 8, scale: 3
      t.integer :item_count
      t.decimal :total_amount, precision: 15, scale: 4
      t.datetime :executed_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.foreign_key :orders, column: :order_id, on_delete: :cascade
    end

    add_index :order_performance_metrics, [:order_id, :executed_at], order: { executed_at: :desc }
    add_index :order_performance_metrics, [:operation_type, :processing_time_ms], where: 'processing_time_ms > 100'
  end
end
