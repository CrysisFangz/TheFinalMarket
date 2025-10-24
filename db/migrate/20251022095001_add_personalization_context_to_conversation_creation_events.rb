class AddPersonalizationContextToConversationCreationEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :conversation_creation_events, :personalization_context, :jsonb
  end
end