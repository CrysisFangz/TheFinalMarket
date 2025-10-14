class AddParentIdToCategories < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:categories, :parent_id)
      add_reference :categories, :parent, null: true, foreign_key: { to_table : :categories }
    end
    add_index :categories, [:parent_id, :name], unique: true unless index_exists?(:categories, [:parent_id, :name])
  end
end
