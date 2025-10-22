# frozen_string_literal: true

class AddMaterializedPathToCategories < ActiveRecord::Migration[7.0]
  def up
    # Add materialized_path column for optimized tree traversal
    add_column :categories, :materialized_path, :string, null: false, default: '/'

    # Add index for materialized_path for fast tree queries
    add_index :categories, :materialized_path, order: { materialized_path: 'ASC' }

    # Add index for parent_id for hierarchical queries
    add_index :categories, :parent_id, order: { parent_id: 'ASC' }

    # Add composite index for name uniqueness within parent
    add_index :categories, [:name, :parent_id], unique: true, order: { name: 'ASC', parent_id: 'ASC' }

    # Populate materialized_path for existing records
    populate_materialized_paths

    # Make materialized_path non-nullable after population
    change_column_null :categories, :materialized_path, false

    # Remove old indexes that are no longer needed
    remove_index :categories, :parent_id if index_exists?(:categories, :parent_id)
  end

  def down
    # Remove materialized_path column and revert to original structure
    remove_column :categories, :materialized_path

    # Note: This migration cannot perfectly reverse due to data transformation
    # The original parent_id-based structure would need manual restoration
  end

  private

  # Populates materialized_path for existing category records
  def populate_materialized_paths
    # Get all categories ordered by their current hierarchy
    categories = Category.all.order(:parent_id, :id)

    categories.each do |category|
      path = calculate_materialized_path(category)
      category.update_column(:materialized_path, path)
    end
  end

  # Calculates the materialized path for a category
  # @param category [Category] the category record
  # @return [String] the calculated materialized path
  def calculate_materialized_path(category)
    if category.parent_id.nil?
      # Root category
      "/#{category.name}/"
    else
      # Child category - build path from parent
      parent = Category.find_by(id: category.parent_id)
      if parent&.materialized_path
        parent.materialized_path + category.name + '/'
      else
        # Fallback if parent path is missing
        "/#{category.name}/"
      end
    end
  end
end