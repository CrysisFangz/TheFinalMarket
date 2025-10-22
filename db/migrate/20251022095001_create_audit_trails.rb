class CreateAuditTrails < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_trails do |t|
      t.string :action
      t.references :record, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.json :changes
      t.json :compliance_context

      t.timestamps
    end
  end
end