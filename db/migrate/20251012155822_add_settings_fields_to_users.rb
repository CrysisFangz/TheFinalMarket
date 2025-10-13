class AddSettingsFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    # Profile fields
    add_column :users, :phone, :string
    add_column :users, :bio, :text
    add_column :users, :avatar_url, :string
    add_column :users, :location, :string
    
    # Notification preferences (default to true for better UX)
    add_column :users, :email_notifications, :boolean, default: true, null: false
    add_column :users, :push_notifications, :boolean, default: true, null: false
    add_column :users, :sms_notifications, :boolean, default: false, null: false
    add_column :users, :order_notifications, :boolean, default: true, null: false
    add_column :users, :promotion_notifications, :boolean, default: false, null: false
    
    # Privacy settings
    add_column :users, :profile_visibility, :string, default: 'public', null: false
    add_column :users, :show_email, :boolean, default: false, null: false
    add_column :users, :show_phone, :boolean, default: false, null: false
    add_column :users, :allow_messages, :boolean, default: true, null: false
    
    # Preference fields
    add_column :users, :theme, :string, default: 'auto', null: false
    
    # Add indexes for commonly queried fields
    add_index :users, :phone
    add_index :users, :profile_visibility
    add_index :users, :theme
  end
end