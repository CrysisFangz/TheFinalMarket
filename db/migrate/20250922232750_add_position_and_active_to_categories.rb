class AddPositionAndActiveToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :position, :integer, default: 0, null: false unless column_exists?(:categories, :position)
    add_column :categories, :active, :boolean, default: true, null: false unless column_exists?(:categories, :active)
    
    add_index :categories, :position unless index_exists?(:categories, :position)
    add_index :categories, :active unless index_exists?(:categories, :active)
  end
end
