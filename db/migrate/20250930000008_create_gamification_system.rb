class CreateGamificationSystem < ActiveRecord::Migration[8.0]
  def change
    # Achievements table
    create_table :achievements do |t|
      t.string :name, null: false
      t.string :identifier, null: false
      t.text :description, null: false
      t.string :icon_url
      t.integer :category, default: 0, null: false
      t.integer :tier, default: 0, null: false
      t.integer :achievement_type, default: 0, null: false
      t.integer :points, default: 0, null: false
      t.integer :reward_coins, default: 0
      t.string :requirement_type
      t.integer :requirement_value
      t.jsonb :unlocks, default: []
      t.boolean :active, default: true
      t.boolean :hidden, default: false
      t.timestamps
    end
    
    add_index :achievements, :identifier, unique: true
    add_index :achievements, :category
    add_index :achievements, :tier
    add_index :achievements, :achievement_type
    add_index :achievements, :active
    
    # User Achievements table
    create_table :user_achievements do |t|
      t.references :user, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true
      t.datetime :earned_at
      t.decimal :progress, precision: 5, scale: 2, default: 0
      t.jsonb :metadata, default: {}
      t.timestamps
    end
    
    add_index :user_achievements, [:user_id, :achievement_id], unique: true
    add_index :user_achievements, :earned_at
    
    # Daily Challenges table
    create_table :daily_challenges do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.integer :challenge_type, null: false
      t.integer :difficulty, default: 0
      t.integer :target_value, null: false
      t.integer :reward_points, default: 0
      t.integer :reward_coins, default: 0
      t.date :active_date, null: false
      t.datetime :expires_at
      t.boolean :active, default: true
      t.jsonb :metadata, default: {}
      t.timestamps
    end
    
    add_index :daily_challenges, :challenge_type
    add_index :daily_challenges, :active_date
    add_index :daily_challenges, :active
    add_index :daily_challenges, [:active_date, :active]
    
    # User Daily Challenges table
    create_table :user_daily_challenges do |t|
      t.references :user, null: false, foreign_key: true
      t.references :daily_challenge, null: false, foreign_key: true
      t.integer :current_value, default: 0
      t.boolean :completed, default: false
      t.datetime :completed_at
      t.timestamps
    end
    
    add_index :user_daily_challenges, [:user_id, :daily_challenge_id], unique: true, name: 'index_user_daily_challenges_unique'
    add_index :user_daily_challenges, :completed
    
    # Leaderboards table
    create_table :leaderboards do |t|
      t.string :name, null: false
      t.integer :leaderboard_type, null: false
      t.integer :period, null: false
      t.text :description
      t.jsonb :snapshot, default: []
      t.datetime :last_updated_at
      t.boolean :active, default: true
      t.timestamps
    end
    
    add_index :leaderboards, :leaderboard_type
    add_index :leaderboards, :period
    add_index :leaderboards, :active
    
    # Points Transactions table (for audit trail)
    create_table :points_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.string :reason
      t.integer :balance_after, null: false
      t.string :source_type
      t.bigint :source_id
      t.timestamps
    end
    
    add_index :points_transactions, [:source_type, :source_id]
    add_index :points_transactions, :created_at
    
    # Coins Transactions table
    create_table :coins_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.string :reason
      t.integer :balance_after, null: false
      t.string :transaction_type # earned, spent, purchased
      t.string :source_type
      t.bigint :source_id
      t.timestamps
    end
    
    add_index :coins_transactions, [:source_type, :source_id]
    add_index :coins_transactions, :transaction_type
    add_index :coins_transactions, :created_at
    
    # Unlocked Features table
    create_table :unlocked_features do |t|
      t.references :user, null: false, foreign_key: true
      t.string :feature_name, null: false
      t.datetime :unlocked_at, null: false
      t.string :unlock_source # achievement, level, purchase
      t.timestamps
    end
    
    add_index :unlocked_features, [:user_id, :feature_name], unique: true
    add_index :unlocked_features, :feature_name
    
    # Add gamification columns to users table
    add_column :users, :coins, :integer, default: 0, null: false
    add_column :users, :current_login_streak, :integer, default: 0, null: false
    add_column :users, :longest_login_streak, :integer, default: 0, null: false
    add_column :users, :last_login_date, :date
    add_column :users, :challenge_streak, :integer, default: 0, null: false
    add_column :users, :total_achievements, :integer, default: 0, null: false
    
    add_index :users, :coins
    add_index :users, :current_login_streak
    add_index :users, :longest_login_streak
  end
end

