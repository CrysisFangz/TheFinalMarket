class CreateBusinessIntelligenceSystem < ActiveRecord::Migration[8.0]
  def change
    # Analytics Reports
    create_table :analytics_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :report_type, null: false, default: 0
      t.integer :category, default: 0
      t.jsonb :configuration, default: {}
      t.jsonb :filters, default: {}
      t.boolean :active, default: true
      t.boolean :scheduled, default: false
      t.boolean :is_public, default: false
      t.integer :execution_count, default: 0
      
      t.timestamps
      
      t.index :report_type
      t.index :category
      t.index :active
      t.index :scheduled
      t.index :is_public
      t.index :created_at
    end
    
    # Report Executions
    create_table :report_executions do |t|
      t.references :analytics_report, null: false, foreign_key: true
      t.datetime :executed_at, null: false
      t.datetime :completed_at
      t.integer :status, default: 0
      t.jsonb :parameters, default: {}
      t.jsonb :result_data, default: {}
      t.text :error_message
      t.integer :execution_time_ms
      
      t.timestamps
      
      t.index :executed_at
      t.index :status
      t.index :created_at
    end
    
    # Analytics Metrics
    create_table :analytics_metrics do |t|
      t.string :metric_name, null: false
      t.integer :metric_type, null: false, default: 0
      t.date :date, null: false
      t.decimal :value, precision: 15, scale: 2, default: 0
      t.jsonb :dimensions, default: {}
      t.jsonb :metadata, default: {}
      
      t.timestamps
      
      t.index [:metric_name, :date], unique: true
      t.index :metric_type
      t.index :date
      t.index :created_at
    end
    
    # Customer Segments
    create_table :customer_segments do |t|
      t.string :name, null: false
      t.text :description
      t.integer :segment_type, null: false, default: 0
      t.jsonb :criteria, default: {}
      t.boolean :active, default: true
      t.boolean :auto_update, default: false
      t.integer :member_count, default: 0
      t.datetime :last_updated_at
      
      t.timestamps
      
      t.index :segment_type
      t.index :active
      t.index :auto_update
      t.index :created_at
    end
    
    # Customer Segment Members
    create_table :customer_segment_members do |t|
      t.references :customer_segment, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :added_at, default: -> { 'CURRENT_TIMESTAMP' }
      
      t.timestamps
      
      t.index [:customer_segment_id, :user_id], unique: true, name: 'index_segment_members_on_segment_and_user'
      t.index :added_at
    end
    
    # Dashboard Widgets
    create_table :dashboard_widgets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :widget_type, null: false
      t.string :title
      t.jsonb :configuration, default: {}
      t.integer :position, default: 0
      t.integer :width, default: 6
      t.integer :height, default: 4
      t.boolean :visible, default: true
      
      t.timestamps
      
      t.index :widget_type
      t.index :position
      t.index :visible
    end
    
    # Data Exports
    create_table :data_exports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :export_type, null: false
      t.string :file_name
      t.string :file_path
      t.integer :status, default: 0
      t.jsonb :parameters, default: {}
      t.integer :record_count, default: 0
      t.integer :file_size_bytes, default: 0
      t.datetime :completed_at
      t.datetime :expires_at
      t.text :error_message
      
      t.timestamps
      
      t.index :export_type
      t.index :status
      t.index :expires_at
      t.index :created_at
    end
    
    # Predictive Models
    create_table :predictive_models do |t|
      t.string :model_name, null: false
      t.string :model_type, null: false
      t.text :description
      t.jsonb :configuration, default: {}
      t.jsonb :training_data, default: {}
      t.jsonb :model_parameters, default: {}
      t.decimal :accuracy, precision: 5, scale: 2
      t.datetime :trained_at
      t.boolean :active, default: true
      t.integer :prediction_count, default: 0
      
      t.timestamps
      
      t.index :model_type
      t.index :active
      t.index :trained_at
    end
    
    # Predictions
    create_table :predictions do |t|
      t.references :predictive_model, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :prediction_type, null: false
      t.jsonb :input_data, default: {}
      t.jsonb :prediction_result, default: {}
      t.decimal :confidence, precision: 5, scale: 2
      t.datetime :predicted_at, null: false
      
      t.timestamps
      
      t.index :prediction_type
      t.index :predicted_at
      t.index :created_at
    end
  end
end

