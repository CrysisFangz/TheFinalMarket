# Enterprise-Grade Categories Migration - Hyperscale Taxonomy Architecture
# Implements: Hierarchical categorization, materialized paths, performance-optimized tree traversal
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    # Enable advanced PostgreSQL extensions for hierarchical data and performance
    enable_extension 'pg_stat_statements' unless extension_enabled?('pg_stat_statements')
    enable_extension 'pg_buffercache' unless extension_enabled?('pg_buffercache')
    enable_extension 'pg_prewarm' unless extension_enabled?('pg_prewarm')
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    enable_extension 'ltree' unless extension_enabled?('ltree')

    # Core categories table with enterprise-grade hierarchical architecture
    create_table :categories, id: :uuid, default: -> { 'uuid_generate_v4()' } do |t|
      # Basic category information with multilingual support
      t.string :name, null: false, limit: 100, comment: 'Category name with unicode and i18n support'
      t.text :description, comment: 'Rich category description with markdown and HTML support'
      t.string :slug, null: false, limit: 120, comment: 'SEO-friendly URL slug with uniqueness constraints'

      # Hierarchical structure using advanced PostgreSQL ltree
      t.ltree :path, null: false, comment: 'Materialized path for efficient hierarchical queries'
      t.integer :parent_id, comment: 'Direct parent category for referential integrity'
      t.integer :depth, default: 0, null: false, comment: 'Depth level in hierarchy tree'
      t.integer :children_count, default: 0, null: false, comment: 'Cached children count for performance'

      # Category management and business logic
      t.boolean :is_active, default: true, null: false, comment: 'Category active status for marketplace visibility'
      t.boolean :is_featured, default: false, comment: 'Featured category for homepage promotion'
      t.boolean :is_root, default: false, null: false, comment: 'Root category designation'
      t.integer :position, default: 0, null: false, comment: 'Display order within same level'
      t.integer :sort_order, default: 0, null: false, comment: 'Custom sort order for flexible arrangement'

      # Multi-tenancy and marketplace support
      t.uuid :tenant_id, comment: 'Multi-tenant isolation for marketplace architecture'
      t.uuid :created_by_id, comment: 'Admin user who created this category'
      t.uuid :updated_by_id, comment: 'Admin user who last updated this category'

      # Advanced category features for enterprise e-commerce
      t.string :category_type, default: 'product', limit: 20, null: false, comment: 'Category type: product, service, digital'
      t.string :visibility_scope, default: 'public', limit: 20, comment: 'Visibility: public, private, restricted'
      t.jsonb :metadata, default: {}, comment: 'Extensible metadata for marketplace flexibility'

      # Image and visual representation
      t.integer :icon_id, comment: 'Category icon attachment for visual navigation'
      t.integer :image_id, comment: 'Category header image for rich presentation'
      t.string :color_code, limit: 7, comment: 'Hex color code for category branding'

      # SEO and marketing optimization
      t.string :meta_title, limit: 60, comment: 'SEO meta title for category pages'
      t.text :meta_description, limit: 160, comment: 'SEO meta description for search results'
      t.jsonb :seo_data, default: {}, comment: 'Additional SEO metadata and structured data'

      # Performance and analytics
      t.bigint :product_count, default: 0, null: false, comment: 'Cached product count for this category'
      t.bigint :view_count, default: 0, null: false, comment: 'Category page view tracking'
      t.datetime :last_product_added_at, comment: 'Timestamp tracking for category freshness'

      # Advanced business logic
      t.decimal :commission_rate, precision: 5, scale: 2, comment: 'Category-specific commission percentage'
      t.decimal :minimum_price, precision: 15, scale: 4, comment: 'Minimum price threshold for products'
      t.decimal :maximum_price, precision: 15, scale: 4, comment: 'Maximum price threshold for products'

      # Status and lifecycle management
      t.integer :status, default: 0, null: false, comment: 'Category lifecycle status with workflow support'
      t.datetime :published_at, comment: 'Publication timestamp for marketplace visibility'
      t.datetime :deprecated_at, comment: 'Deprecation notice for category migration planning'
      t.datetime :deleted_at, index: true, comment: 'Soft delete with performance indexing'

      # Audit compliance
      t.datetime :approved_at, comment: 'Admin approval timestamp for governance'
      t.uuid :approved_by_id, comment: 'Admin who approved this category'

      # Hyperscale performance timestamps
      t.datetime :created_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.datetime :updated_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false

      # Performance optimization columns
      t.tsvector :search_vector, comment: 'Full-text search vector for category search'
    end

    # Enterprise-grade performance indexes for hyperscale hierarchical operations
    # Composite indexes for complex hierarchical query patterns
    add_index :categories, [:path], using: :gist, comment: 'Hierarchical path queries with ltree for O(log n) traversal'
    add_index :categories, [:parent_id, :position], where: 'is_active = true AND deleted_at IS NULL', comment: 'Sibling navigation and ordering'
    add_index :categories, [:tenant_id, :is_active, :status], comment: 'Multi-tenant category management'
    add_index :categories, [:slug], unique: true, where: 'deleted_at IS NULL', comment: 'SEO slug uniqueness for URL routing'
    add_index :categories, [:depth, :is_active], comment: 'Depth-based filtering and navigation'
    add_index :categories, [:is_featured, :position], where: 'is_active = true', comment: 'Featured category promotion queries'
    add_index :categories, [:product_count], where: 'product_count > 0', comment: 'Category product count optimization'
    add_index :categories, [:view_count, :is_active], comment: 'Popular category analytics and recommendations'

    # Advanced search indexes
    add_index :categories, :search_vector, using: :gin, comment: 'Full-text category search with ranking'
    add_index :categories, :metadata, using: :gin, comment: 'Metadata-based category filtering'

    # Partial indexes for performance optimization
    add_index :categories, [:published_at], where: 'published_at IS NOT NULL AND is_active = true', comment: 'Published category queries'
    add_index :categories, [:deprecated_at], where: 'deprecated_at IS NOT NULL', comment: 'Deprecated category management'

    # Foreign key constraints with cascade behavior for referential integrity
    add_foreign_key :categories, :categories, column: :parent_id, on_delete: :cascade
    add_foreign_key :categories, :users, column: :created_by_id, on_delete: :set_null
    add_foreign_key :categories, :users, column: :updated_by_id, on_delete: :set_null
    add_foreign_key :categories, :users, column: :approved_by_id, on_delete: :set_null

    # Sophisticated check constraints for hierarchical data integrity
    execute <<-SQL
      ALTER TABLE categories ADD CONSTRAINT categories_depth_check
      CHECK (depth >= 0 AND depth <= 10)
    SQL

    execute <<-SQL
      ALTER TABLE categories ADD CONSTRAINT categories_position_check
      CHECK (position >= 0 AND position <= 99999)
    SQL

    execute <<-SQL
      ALTER TABLE categories ADD CONSTRAINT categories_status_check
      CHECK (status IN (0, 1, 2, 3, 4))
    SQL

    execute <<-SQL
      ALTER TABLE categories ADD CONSTRAINT categories_commission_rate_check
      CHECK (commission_rate >= 0 AND commission_rate <= 100)
    SQL

    execute <<-SQL
      ALTER TABLE categories ADD CONSTRAINT categories_category_type_check
      CHECK (category_type IN ('product', 'service', 'digital', 'subscription'))
    SQL

    # Advanced constraint for hierarchical consistency
    execute <<-SQL
      ALTER TABLE categories ADD CONSTRAINT categories_hierarchical_consistency_check
      CHECK (
        (parent_id IS NULL AND depth = 0 AND is_root = true) OR
        (parent_id IS NOT NULL AND depth > 0 AND is_root = false)
      )
    SQL

    # Constraint for temporal consistency
    execute <<-SQL
      ALTER TABLE categories ADD CONSTRAINT categories_temporal_consistency_check
      CHECK (updated_at >= created_at)
    SQL

    # Create comprehensive audit and path maintenance triggers
    execute <<-SQL
      CREATE OR REPLACE FUNCTION maintain_category_path() RETURNS trigger AS $$
      DECLARE
        parent_path ltree;
        new_path ltree;
      BEGIN
        -- Get parent path or use empty path for root categories
        IF NEW.parent_id IS NOT NULL THEN
          SELECT path INTO parent_path FROM categories WHERE id = NEW.parent_id;
          new_path := parent_path || NEW.id::text;
        ELSE
          new_path := NEW.id::text::ltree;
        END IF;

        NEW.path := new_path;
        NEW.depth := nlevel(new_path) - 1;

        -- Update search vector for full-text search
        NEW.search_vector := to_tsvector('english',
          COALESCE(NEW.name, '') || ' ' ||
          COALESCE(NEW.description, '')
        );

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply path maintenance trigger
    execute <<-SQL
      CREATE TRIGGER category_path_maintenance_trigger
        BEFORE INSERT OR UPDATE ON categories
        FOR EACH ROW EXECUTE FUNCTION maintain_category_path()
    SQL

    # Function to update children paths when parent path changes
    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_children_category_paths() RETURNS trigger AS $$
      DECLARE
        old_child_path ltree;
        new_child_path ltree;
      BEGIN
        -- Only process if path actually changed
        IF OLD.path != NEW.path THEN
          -- Update all children paths
          FOR old_child_path, new_child_path IN
            SELECT
              child.path,
              NEW.path || subpath(child.path, nlevel(OLD.path))
            FROM categories child
            WHERE child.path <@ OLD.path AND child.id != OLD.id
          LOOP
            UPDATE categories SET path = new_child_path WHERE path = old_child_path;
          END LOOP;
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply children path update trigger
    execute <<-SQL
      CREATE TRIGGER update_children_paths_trigger
        AFTER UPDATE ON categories
        FOR EACH ROW EXECUTE FUNCTION update_children_category_paths()
    SQL

    # Performance monitoring for category operations
    create_table :category_performance_metrics, id: false do |t|
      t.uuid :category_id, null: false
      t.string :operation_type, null: false, limit: 50
      t.integer :affected_rows, default: 0
      t.decimal :execution_time_ms, precision: 8, scale: 3
      t.datetime :executed_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
      t.foreign_key :categories, column: :category_id, on_delete: :cascade
    end

    add_index :category_performance_metrics, [:category_id, :executed_at], order: { executed_at: :desc }
    add_index :category_performance_metrics, [:operation_type, :execution_time_ms], where: 'execution_time_ms > 50'

    # Category hierarchy cache for performance optimization
    create_table :category_hierarchy_cache, id: false do |t|
      t.uuid :ancestor_id, null: false
      t.uuid :descendant_id, null: false
      t.integer :depth, null: false
      t.datetime :cached_at, precision: 6, default: -> { 'CURRENT_TIMESTAMP(6)' }, null: false
    end

    add_index :category_hierarchy_cache, [:ancestor_id, :descendant_id], unique: true
    add_index :category_hierarchy_cache, [:descendant_id, :depth]
    add_index :category_hierarchy_cache, :cached_at, where: 'cached_at < CURRENT_TIMESTAMP - INTERVAL \'1 hour\''

    # Function to maintain hierarchy cache
    execute <<-SQL
      CREATE OR REPLACE FUNCTION maintain_category_hierarchy_cache() RETURNS trigger AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          DELETE FROM category_hierarchy_cache
          WHERE ancestor_id = OLD.id OR descendant_id = OLD.id;
          RETURN OLD;
        END IF;

        -- Rebuild cache for affected category tree
        IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
          -- Delete existing cache entries for this category
          DELETE FROM category_hierarchy_cache WHERE descendant_id = NEW.id;

          -- Insert new cache entries
          INSERT INTO category_hierarchy_cache (ancestor_id, descendant_id, depth, cached_at)
          SELECT
            ancestor.id,
            NEW.id,
            nlevel(subpath(NEW.path, nlevel(ancestor.path))) - 1,
            CURRENT_TIMESTAMP(6)
          FROM categories ancestor
          WHERE ancestor.path @> NEW.path AND ancestor.id != NEW.id;
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply hierarchy cache maintenance trigger
    execute <<-SQL
      CREATE TRIGGER category_hierarchy_cache_trigger
        AFTER INSERT OR UPDATE OR DELETE ON categories
        FOR EACH ROW EXECUTE FUNCTION maintain_category_hierarchy_cache()
    SQL
  end
end
