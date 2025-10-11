class CreateSocialResponsibilitySystem < ActiveRecord::Migration[8.0]
  def change
    create_table :charities do |t|
      t.string :name, null: false
      t.string :ein, null: false
      t.text :description
      t.integer :category, null: false
      t.string :website
      t.boolean :verified, default: false
      t.integer :total_donations_cents, default: 0
      
      t.timestamps
      
      t.index :ein, unique: true
      t.index :category
      t.index :verified
    end
    
    create_table :charity_donations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :charity, null: false, foreign_key: true
      t.references :order, foreign_key: true
      t.integer :amount_cents, null: false
      t.integer :donation_type, default: 0
      t.boolean :processed, default: false
      t.datetime :processed_at
      
      t.timestamps
      
      t.index :donation_type
      t.index :processed
    end
    
    create_table :charity_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :selected_charity, foreign_key: { to_table: :charities }
      t.boolean :round_up_enabled, default: false
      t.integer :monthly_donation_cents, default: 0
      t.integer :percentage_donation, default: 0
      
      t.timestamps
    end
    
    create_table :local_businesses do |t|
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.string :business_name, null: false
      t.string :address
      t.string :city, null: false
      t.string :state, null: false
      t.string :zip_code
      t.boolean :verified, default: false
      t.datetime :verified_at
      
      t.timestamps
      
      t.index :city
      t.index :state
      t.index :verified
    end
    
    create_table :community_initiatives do |t|
      t.string :title, null: false
      t.text :description
      t.integer :initiative_type, default: 0
      t.integer :goal_cents
      t.integer :raised_cents, default: 0
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :status, default: 0
      
      t.timestamps
      
      t.index :initiative_type
      t.index :status
    end
    
    create_table :transparency_reports do |t|
      t.date :report_date, null: false
      t.integer :report_type, default: 0
      t.jsonb :metrics, default: {}
      t.text :summary
      t.boolean :published, default: false
      
      t.timestamps
      
      t.index :report_date
      t.index :report_type
      t.index :published
    end
  end
end

