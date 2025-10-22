class CreateConversationCreationEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_creation_events do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end