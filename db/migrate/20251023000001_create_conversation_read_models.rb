class CreateConversationReadModels < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_read_models do |t|
      t.string :conversation_id, null: false, index: { unique: true }
      t.bigint :sender_id, null: false, foreign_key: { to_table: :users }
      t.bigint :recipient_id, null: false, foreign_key: { to_table: :users }
      t.string :conversation_type, null: false, default: 'direct'
      t.integer :participant_count, null: false, default: 2
      t.datetime :created_at, null: false
      t.datetime :last_activity_at, null: false
      t.datetime :last_read_at
      t.string :status, null: false, default: 'active'
      t.integer :unread_count, null: false, default: 0

      t.timestamps

      # Indexes for performance
      t.index :sender_id
      t.index :recipient_id
      t.index :conversation_type
      t.index :status
      t.index :last_activity_at
      t.index :unread_count
      t.index [:sender_id, :status]
      t.index [:recipient_id, :status]
    end
  end
end