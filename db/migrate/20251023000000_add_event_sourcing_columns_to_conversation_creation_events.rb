class AddEventSourcingColumnsToConversationCreationEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :conversation_creation_events, :event_type, :string, null: false, default: 'conversation_created'
    add_column :conversation_creation_events, :data, :jsonb, null: false, default: {}
    add_column :conversation_creation_events, :metadata, :jsonb, null: false, default: {}
    add_column :conversation_creation_events, :sequence_number, :integer, null: false, default: 1
    add_column :conversation_creation_events, :entity_type, :string
    add_column :conversation_creation_events, :entity_id, :string

    # Add indexes for performance
    add_index :conversation_creation_events, :event_type
    add_index :conversation_creation_events, :sequence_number
    add_index :conversation_creation_events, [:entity_type, :entity_id]
    add_index :conversation_creation_events, :conversation_id
    add_index :conversation_creation_events, :creator_id
    add_index :conversation_creation_events, :created_at

    # Unique index for sequence number per entity
    add_index :conversation_creation_events, [:entity_type, :entity_id, :sequence_number], unique: true, name: 'index_conversation_events_on_entity_and_sequence'
  end
end