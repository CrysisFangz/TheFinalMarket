class CreateDeadLetterEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :dead_letter_events do |t|
      t.string :original_event_id, null: false
      t.string :original_event_type, null: false
      t.string :event_type, null: false
      t.text :error_message, null: false
      t.text :error_backtrace
      t.integer :retry_count, null: false, default: 0
      t.jsonb :event_data, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :reprocessed_at
      t.string :status, null: false, default: 'failed'
      t.datetime :created_at, null: false

      t.timestamps

      # Indexes
      t.index :event_type
      t.index :status
      t.index :retry_count
      t.index :created_at
      t.index [:event_type, :status]
    end
  end
end