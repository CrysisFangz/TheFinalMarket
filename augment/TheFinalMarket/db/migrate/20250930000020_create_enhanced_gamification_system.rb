class CreateEnhancedGamificationSystem < ActiveRecord::Migration[8.0]
  def change
    # Treasure Hunts
    create_table :treasure_hunts do |t|
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :difficulty, default: 0, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :max_participants
      t.integer :prize_pool, default: 0
      t.jsonb :metadata, default: {}
      t.timestamps
    end
    
    create_table :treasure_hunt_clues do |t|
      t.references :treasure_hunt, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.references :category, foreign_key: true
      t.integer :clue_order, null: false
      t.integer :clue_type, null: false
      t.text :clue_text, null: false
      t.text :hint_text
      t.string :correct_answer
      t.string :qr_code_value
      t.string :image_url
      t.jsonb :clue_data, default: {}
      t.timestamps
    end
    
    create_table :treasure_hunt_participations do |t|
      t.references :treasure_hunt, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.boolean :completed, default: false
      t.integer :clues_found, default: 0
      t.integer :current_clue_index, default: 0
      t.integer :incorrect_attempts, default: 0
      t.integer :hints_used, default: 0
      t.integer :time_taken_seconds
      t.integer :rank
      t.timestamps
    end
    
    create_table :clue_attempts do |t|
      t.references :treasure_hunt_participation, null: false, foreign_key: true
      t.references :treasure_hunt_clue, null: false, foreign_key: true
      t.string :answer
      t.boolean :correct, default: false
      t.datetime :attempted_at, null: false
      t.timestamps
    end
    
    # Spin to Win
    create_table :spin_to_wins do |t|
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :spins_per_user_per_day, default: 1
      t.boolean :requires_purchase, default: false
      t.jsonb :config, default: {}
      t.timestamps
    end
    
    create_table :spin_to_win_prizes do |t|
      t.references :spin_to_win, null: false, foreign_key: true
      t.string :prize_name, null: false
      t.integer :prize_type, null: false
      t.integer :prize_value, default: 0
      t.decimal :probability, precision: 5, scale: 2, default: 10.0
      t.boolean :active, default: true
      t.string :image_url
      t.jsonb :prize_data, default: {}
      t.timestamps
    end
    
    create_table :spin_to_win_spins do |t|
      t.references :spin_to_win, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :spin_to_win_prize, null: false, foreign_key: true
      t.datetime :spun_at, null: false
      t.timestamps
    end
    
    # Shopping Quests
    create_table :shopping_quests do |t|
      t.string :name, null: false
      t.text :description
      t.integer :quest_type, null: false
      t.integer :status, default: 0, null: false
      t.integer :difficulty, default: 0
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :required_level
      t.integer :reward_coins, default: 0
      t.integer :reward_experience, default: 0
      t.integer :reward_tokens, default: 0
      t.jsonb :reward_items, default: []
      t.bigint :unlocks_achievement_id
      t.jsonb :metadata, default: {}
      t.timestamps
    end
    
    create_table :quest_objectives do |t|
      t.references :shopping_quest, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.references :category, foreign_key: true
      t.integer :objective_type, null: false
      t.text :description, null: false
      t.integer :target_value, null: false
      t.integer :objective_order, default: 0
      t.jsonb :objective_data, default: {}
      t.timestamps
    end
    
    create_table :quest_participations do |t|
      t.references :shopping_quest, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.boolean :completed, default: false
      t.decimal :progress, precision: 5, scale: 2, default: 0.0
      t.timestamps
    end
    
    # Seasonal Events
    create_table :seasonal_events do |t|
      t.string :name, null: false
      t.text :description
      t.integer :event_type, null: false
      t.integer :status, default: 0, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :started_at
      t.datetime :ended_at
      t.string :theme
      t.string :banner_url
      t.jsonb :event_data, default: {}
      t.timestamps
    end
    
    create_table :event_challenges do |t|
      t.references :seasonal_event, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :challenge_type, null: false
      t.integer :points_reward, default: 0
      t.integer :bonus_coins, default: 0
      t.boolean :active, default: true
      t.boolean :repeatable, default: false
      t.integer :completion_count, default: 0
      t.jsonb :challenge_data, default: {}
      t.timestamps
    end
    
    create_table :challenge_completions do |t|
      t.references :event_challenge, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :completed_at, null: false
      t.timestamps
    end
    
    create_table :event_participations do |t|
      t.references :seasonal_event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :joined_at, null: false
      t.integer :points, default: 0
      t.integer :rank, default: 0
      t.timestamps
    end
    
    create_table :event_rewards do |t|
      t.references :seasonal_event, null: false, foreign_key: true
      t.integer :reward_type, null: false
      t.string :reward_name, null: false
      t.text :description
      t.integer :threshold
      t.integer :rank
      t.string :prize_type
      t.integer :prize_value, default: 0
      t.jsonb :reward_data, default: {}
      t.timestamps
    end
    
    create_table :claimed_event_rewards do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event_reward, null: false, foreign_key: true
      t.datetime :claimed_at, null: false
      t.timestamps
    end
    
    # Social Competitions
    create_table :social_competitions do |t|
      t.string :name, null: false
      t.text :description
      t.integer :competition_type, null: false
      t.integer :status, default: 0, null: false
      t.integer :scoring_type, default: 0
      t.datetime :registration_ends_at
      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :max_participants
      t.integer :prize_pool, default: 0
      t.integer :prize_positions, default: 3
      t.jsonb :rules, default: {}
      t.timestamps
    end
    
    create_table :competition_participants do |t|
      t.references :social_competition, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :competition_team, foreign_key: true
      t.datetime :registered_at, null: false
      t.integer :score, default: 0
      t.integer :rank, default: 0
      t.timestamps
    end
    
    create_table :competition_teams do |t|
      t.references :social_competition, null: false, foreign_key: true
      t.references :captain, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :description
      t.integer :max_members
      t.integer :total_score, default: 0
      t.string :team_color
      t.string :team_logo_url
      t.timestamps
    end
    
    # Indexes
    add_index :treasure_hunts, :status
    add_index :treasure_hunts, :difficulty
    add_index :treasure_hunts, [:starts_at, :ends_at]
    
    add_index :treasure_hunt_clues, [:treasure_hunt_id, :clue_order], unique: true
    
    add_index :treasure_hunt_participations, [:treasure_hunt_id, :user_id], unique: true, name: 'index_hunt_participations_on_hunt_and_user'
    add_index :treasure_hunt_participations, :completed
    add_index :treasure_hunt_participations, :rank
    
    add_index :spin_to_wins, :status
    add_index :spin_to_win_spins, [:user_id, :spun_at]
    
    add_index :shopping_quests, :quest_type
    add_index :shopping_quests, :status
    add_index :shopping_quests, [:starts_at, :ends_at]
    
    add_index :quest_participations, [:shopping_quest_id, :user_id], unique: true, name: 'index_quest_participations_on_quest_and_user'
    add_index :quest_participations, :completed
    
    add_index :seasonal_events, :event_type
    add_index :seasonal_events, :status
    add_index :seasonal_events, [:starts_at, :ends_at]
    
    add_index :event_participations, [:seasonal_event_id, :user_id], unique: true, name: 'index_event_participations_on_event_and_user'
    add_index :event_participations, [:points, :rank]
    
    add_index :challenge_completions, [:event_challenge_id, :user_id]
    
    add_index :social_competitions, :competition_type
    add_index :social_competitions, :status
    add_index :social_competitions, [:starts_at, :ends_at]
    
    add_index :competition_participants, [:social_competition_id, :user_id], unique: true, name: 'index_comp_participants_on_comp_and_user'
    add_index :competition_participants, [:score, :rank]
    
    add_index :competition_teams, [:social_competition_id, :name], unique: true
  end
end

