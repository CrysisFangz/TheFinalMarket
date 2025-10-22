class AddEnhancedBondFields < ActiveRecord::Migration[8.0]
  def change
    # Enhanced financial risk assessment
    add_column :bonds, :financial_risk_score, :decimal, precision: 5, scale: 4, default: 0.0, null: false

    # Additional reason fields for better audit trails
    add_column :bonds, :return_reason, :text
    add_column :bonds, :dispute_reason, :text

    # Version tracking for event sourcing
    add_column :bonds, :version, :integer, default: 1, null: false

    # Cryptographic signature for state immutability
    add_column :bonds, :hash_signature, :string, limit: 128

    # Structured financial impact data
    add_column :bonds, :financial_impact_data, :jsonb, default: {}

    # Enhanced processing stage tracking
    add_column :bonds, :processing_stage, :string, default: 'initialized', null: false

    # Enhanced indexing for performance optimization
    add_index :bonds, :financial_risk_score
    add_index :bonds, :processing_stage
    add_index :bonds, :version
    add_index :bonds, [:status, :processing_stage]
    add_index :bonds, [:user_id, :status, :created_at]

    # Partial indexes for active bonds requiring attention
    add_index :bonds, :created_at, where: "status IN ('pending', 'active') AND financial_risk_score > 0.5"
    add_index :bonds, :paid_at, where: "status = 'active'"

    # Composite indexes for common query patterns
    add_index :bonds, [:status, :created_at, :amount_cents]
    add_index :bonds, [:user_id, :status, :processing_stage]
  end
end