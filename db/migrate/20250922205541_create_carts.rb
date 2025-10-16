# Enterprise-Grade Carts Migration - Hyperscale Shopping Cart Architecture
# Implements: Advanced cart management, guest carts, cart recovery, performance optimization
class CreateCarts < ActiveRecord::Migration[8.0]
  def change
    # Enable advanced PostgreSQL extensions for enterprise cart functionality
    enable_extension 'pg_stat_statements' unless extension_enabled?('pg_stat_statements')
    enable_extension 'pg_buffercache' unless extension_enabled?('pg_buffercache')
    enable_extension 'pg_prewarm' unless extension_enabled?('pg_prewarm')
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Core carts table with enterprise-grade e-commerce architecture
    create_table :carts, id: :uuid, default: -> { 'uuid_generate_v4()' } do |t|
      # User association and cart type management
      t.uuid :user_id, comment: 'Associated user for authenticated carts'
      t.uuid :session_id, comment: 'Session identifier for guest carts'
      t.string :cart_type, default: 'user', limit: 20, null: false, comment: 'Cart type: user, guest, wishlist'

      # Multi-tenancy support for marketplace architecture
      t.uuid :tenant_id, comment: 'Multi-tenant isolation for marketplace'
      t.uuid :seller_id, comment: 'Primary seller context for mixed carts'

      # Cart status and lifecycle management
      t.integer :status, default: 0, null: false, comment: 'Cart lifecycle status with workflow support'
      t.datetime :abandoned_at, comment: 'Cart abandonment timestamp for analytics'
      t.datetime :recovered_at, comment: 'Cart recovery timestamp for conversion tracking'
      t.datetime :converted_at, comment: 'Cart conversion timestamp for attribution'

      # Advanced cart features for enterprise e-commerce
      t.decimal :subtotal, precision: 15, scale: 4, default: 0.0, null: false, comment: 'Pre-tax, pre-discount subtotal'
      t.decimal :tax_amount, precision: 15, scale: 4, default: 0.0, null: false, comment: 'Calculated tax amount'
      t.decimal :shipping_amount, precision: 15, scale: 4, default: 0.0, null: false, comment: 'Calculated shipping cost'
      t.decimal :discount_amount, precision: 15, scale: 4, default: 0.0, null: false, comment: 'Total discount applied'
      t.decimal :total_amount, precision: 15, scale: 4, default: 0.0, null: false, comment: 'Final cart total'

      # Currency and regional pricing
      t.string :currency, default: 'USD', limit: 3, null: false, comment: 'ISO 4217 currency code'
      t.jsonb :exchange_rates, default: {}, comment: 'Cached exchange rates for international carts'

      # Geographic and shipping context
      t.string :shipping_country, limit: 3, comment: 'ISO 3166-1 alpha-3 shipping destination'
      t.string :shipping_region, limit: 10, comment: 'Shipping region for tax and shipping calculations'
      t.jsonb :shipping_address, default: {}, comment: 'Structured shipping address for validation'

      # Advanced cart features
      t.jsonb :applied_coupons, default: [], comment: 'Applied coupon and discount codes'
      t.jsonb :applied_promotions, default: [], comment: 'Applied promotional offers and rules'
      t.jsonb :cart_items, default: [], comment: 'Cart item snapshots for crash recovery'
      t.integer :item_count, default: 0, null: false, comment: 'Cached item count for performance'

      # Guest cart recovery and attribution
      t.string :guest_token, limit: 64, comment: 'Secure token for guest cart recovery'
      t.string :referral_source, limit: 100, comment: 'Marketing attribution source'
      t.jsonb :utm_parameters, default: {}, comment: 'UTM tracking parameters for attribution'

      # Performance and analytics tracking
      t.datetime :last_activity_at, comment: 'Last cart modification for abandonment detection'
      t.datetime :last_calculated_at, comment: 'Last price calculation timestamp'
      t.integer :calculation_version, default: 0, comment: 'Price calculation version for cache invalidation'

      # Cart expiration and cleanup
      t.datetime :expires_at, comment: 'Cart expiration timestamp for cleanup'
      t.datetime :last_reminder_sent_at, comment: 'Abandonment reminder timestamp'
      t.integer :reminder_count, default: 0, comment: 'Number of abandonment reminders sent'

      # Advanced business logic
      t.boolean :requires_shipping, default: true, comment: 'Whether cart contains shippable items'
      t.boolean :is_gift, default: false, comment: 'Gift cart designation for special handling'
      t.text :gift_message, comment: 'Gift message for gift carts'
      t.string :gift_recipient_email, limit: 254, comment: 'Gift recipient email for notifications'

      # Audit trail and compliance
      t.uuid :created_by_id, comment: 'User ID who created this cart record'
      t.uuid :updated_by_id, comment: 'User ID who last updated this cart record'
      t.datetime :deleted_at, index: true, comment: 'Soft delete with performance indexing'

      # Hyperscale performance timestamps
      t.datetime :created_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.datetime :updated_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
    end

    # Enterprise-grade performance indexes for hyperscale cart operations
    # Composite indexes for complex cart query patterns
    add_index :carts, [:user_id, :status], where: 'deleted_at IS NULL', comment: 'User cart management and status filtering'
    add_index :carts, [:session_id, :cart_type], where: 'deleted_at IS NULL', comment: 'Guest cart lookup and recovery'
    add_index :carts, [:tenant_id, :status], where: 'deleted_at IS NULL', comment: 'Multi-tenant cart isolation'
    add_index :carts, [:expires_at, :status], where: 'expires_at IS NOT NULL', comment: 'Cart expiration cleanup queries'
    add_index :carts, [:abandoned_at, :last_reminder_sent_at], comment: 'Cart abandonment analytics and recovery'
    add_index :carts, [:last_activity_at, :status], order: { last_activity_at: :desc }, comment: 'Active cart identification'
    add_index :carts, [:guest_token], unique: true, where: 'guest_token IS NOT NULL', comment: 'Guest cart token uniqueness'

    # Partial indexes for performance optimization
    add_index :carts, [:converted_at], where: 'converted_at IS NOT NULL', comment: 'Converted cart analytics'
    add_index :carts, [:recovered_at], where: 'recovered_at IS NOT NULL', comment: 'Recovered cart tracking'

    # JSONB indexes for advanced cart features
    add_index :carts, :applied_coupons, using: :gin, comment: 'Coupon filtering and validation'
    add_index :carts, :applied_promotions, using: :gin, comment: 'Promotion rule evaluation'

    # Foreign key constraints with cascade behavior
    add_foreign_key :carts, :users, column: :user_id, on_delete: :cascade
    add_foreign_key :carts, :users, column: :created_by_id, on_delete: :set_null
    add_foreign_key :carts, :users, column: :updated_by_id, on_delete: :set_null

    # Sophisticated check constraints for data integrity
    execute <<-SQL
      ALTER TABLE carts ADD CONSTRAINT carts_type_check
      CHECK (cart_type IN ('user', 'guest', 'wishlist', 'saved'))
    SQL

    execute <<-SQL
      ALTER TABLE carts ADD CONSTRAINT carts_status_check
      CHECK (status IN (0, 1, 2, 3, 4, 5))
    SQL

    execute <<-SQL
      ALTER TABLE carts ADD CONSTRAINT carts_amounts_check
      CHECK (subtotal >= 0 AND tax_amount >= 0 AND shipping_amount >= 0 AND discount_amount >= 0 AND total_amount >= 0)
    SQL

    execute <<-SQL
      ALTER TABLE carts ADD CONSTRAINT carts_currency_check
      CHECK (length(currency) = 3 AND currency ~ '^[A-Z]+$')
    SQL

    # Advanced constraint for temporal consistency
    execute <<-SQL
      ALTER TABLE carts ADD CONSTRAINT carts_temporal_consistency_check
      CHECK (updated_at >= created_at)
    SQL

    # Cart audit triggers for comprehensive tracking
    execute <<-SQL
      CREATE OR REPLACE FUNCTION audit_carts_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP(6);
        NEW.last_activity_at = CURRENT_TIMESTAMP(6);

        -- Calculate item count from cart_items JSONB
        IF NEW.cart_items IS NOT NULL THEN
          NEW.item_count = jsonb_array_length(NEW.cart_items);
        END IF;

        IF TG_OP = 'INSERT' THEN
          NEW.created_at = CURRENT_TIMESTAMP(6);
          -- Set expiration for guest carts
          IF NEW.cart_type = 'guest' AND NEW.expires_at IS NULL THEN
            NEW.expires_at = CURRENT_TIMESTAMP(6) + INTERVAL '30 days';
          END IF;
          RETURN NEW;
        ELSIF TG_OP = 'UPDATE' THEN
          -- Mark as abandoned if inactive for 24 hours
          IF OLD.status = 0 AND NEW.status = 0 AND
             NEW.last_activity_at < CURRENT_TIMESTAMP(6) - INTERVAL '24 hours' THEN
            NEW.abandoned_at = CURRENT_TIMESTAMP(6);
          END IF;
          RETURN NEW;
        END IF;
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply audit trigger
    execute <<-SQL
      CREATE TRIGGER carts_audit_trigger
        BEFORE INSERT OR UPDATE ON carts
        FOR EACH ROW EXECUTE FUNCTION audit_carts_trigger()
    SQL

    # Performance monitoring for cart operations
    create_table :cart_performance_metrics, id: false do |t|
      t.uuid :cart_id, null: false
      t.string :operation_type, null: false, limit: 50
      t.decimal :calculation_time_ms, precision: 8, scale: 3
      t.integer :item_count
      t.datetime :executed_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.foreign_key :carts, column: :cart_id, on_delete: :cascade
    end

    add_index :cart_performance_metrics, [:cart_id, :executed_at], order: { executed_at: :desc }
    add_index :cart_performance_metrics, [:operation_type, :calculation_time_ms], where: 'calculation_time_ms > 100'
  end
end
