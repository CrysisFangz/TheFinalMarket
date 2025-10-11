class CreateHyperPersonalizationSystem < ActiveRecord::Migration[8.0]
  def change
    create_table :personalization_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :product_interests, default: {}
      t.jsonb :search_history, default: []
      t.jsonb :purchase_history, default: []
      t.jsonb :cart_history, default: []
      t.jsonb :wishlist_history, default: []
      t.datetime :last_purchase_at
      t.integer :lifetime_value_score, default: 0
      t.integer :purchase_frequency_score, default: 0
      t.integer :price_sensitivity_score, default: 50
      t.integer :brand_loyalty_score, default: 50
      t.integer :impulse_buying_score, default: 50
      t.integer :research_intensity_score, default: 50
      t.integer :weekend_shopping_score, default: 50
      t.integer :night_shopping_score, default: 50
      t.integer :mobile_usage_score, default: 50
      
      t.timestamps
      
      t.index :last_purchase_at
    end
    
    create_table :user_segments do |t|
      t.references :personalization_profile, null: false, foreign_key: true
      t.string :segment_name, null: false
      t.datetime :assigned_at
      
      t.timestamps
      
      t.index :segment_name
    end
    
    create_table :personalized_recommendations do |t|
      t.references :personalization_profile, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :score, default: 0
      t.string :reason
      t.boolean :clicked, default: false
      t.boolean :purchased, default: false
      
      t.timestamps
      
      t.index :score
      t.index :clicked
      t.index :purchased
    end
    
    create_table :behavioral_events do |t|
      t.references :personalization_profile, null: false, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :event_data, default: {}
      t.datetime :occurred_at
      
      t.timestamps
      
      t.index :event_type
      t.index :occurred_at
    end
  end
end

