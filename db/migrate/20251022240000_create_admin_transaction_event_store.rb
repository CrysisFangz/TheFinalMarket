# frozen_string_literal: true

# Migration for admin transaction event store and read model
# Creates tables for event sourcing architecture
class CreateAdminTransactionEventStore < ActiveRecord::Migration[7.1]
  def change
    # Event store table for immutable event sourcing
    create_table :admin_transaction_event_store, id: false do |t|
      t.string :aggregate_id, null: false, index: true
      t.string :event_id, null: false, index: { unique: true }
      t.string :event_type, null: false, index: true
      t.jsonb :event_data, null: false
      t.integer :version, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps

      # Composite indexes for performance
      t.index [:aggregate_id, :version], unique: true
      t.index [:event_type, :occurred_at]
      t.index :occurred_at
    end

    # Read model table for efficient querying
    create_table :admin_transaction_read_models do |t|
      t.string :transaction_id, null: false, index: { unique: true }
      t.integer :admin_id, null: false
      t.integer :requested_by_id, null: false
      t.string :approvable_type
      t.integer :approvable_id
      t.string :action, null: false
      t.text :reason, null: false
      t.text :justification
      t.decimal :amount, precision: 15, scale: 2
      t.string :currency, limit: 3
      t.string :urgency, null: false, default: 'medium'
      t.string :status, null: false, default: 'draft'
      t.jsonb :compliance_flags, null: false, default: []
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.integer :approved_by_id
      t.datetime :approved_at
      t.text :final_comments
      t.integer :version, null: false, default: 0

      t.timestamps

      # Performance indexes
      t.index :created_at
      t.index [:admin_id, :created_at]
      t.index [:status, :created_at]
      t.index [:urgency, :created_at]
      t.index [:action, :status]
      t.index [:amount, :created_at]
      t.index :updated_at

      # Partial indexes for specific use cases
      t.index :amount, where: "amount IS NOT NULL"
      t.index :approved_by_id, where: "status = 'approved'"
      t.index :compliance_flags, where: "jsonb_array_length(compliance_flags) > 0"
    end
  end
end