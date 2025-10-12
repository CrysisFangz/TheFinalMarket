# frozen_string_literal: true

class AddSecurityFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :failed_login_attempts, :integer, default: 0, null: false
    add_column :users, :locked_until, :datetime
    add_column :users, :last_login_at, :datetime
    
    # Add indexes for performance
    add_index :users, :locked_until
    add_index :users, :last_login_at
  end
end