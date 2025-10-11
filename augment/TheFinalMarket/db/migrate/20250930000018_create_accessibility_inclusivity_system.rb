class CreateAccessibilityInclusivitySystem < ActiveRecord::Migration[8.0]
  def change
    # Accessibility Settings
    create_table :accessibility_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      
      # Visual preferences
      t.integer :font_size, default: 1 # medium
      t.integer :contrast_mode, default: 0 # normal
      t.integer :font_family, default: 0 # default
      
      # Spacing and layout
      t.decimal :line_height_value, precision: 3, scale: 2, default: 1.5
      t.decimal :letter_spacing_value, precision: 3, scale: 2, default: 0.0
      t.decimal :text_spacing_value, precision: 3, scale: 2, default: 1.0
      
      # Feature flags
      t.boolean :reduce_motion, default: false
      t.boolean :screen_reader_optimized, default: false
      t.boolean :keyboard_navigation_enabled, default: true
      t.boolean :high_contrast_enabled, default: false
      t.boolean :skip_to_content_enabled, default: true
      t.boolean :aria_labels_enabled, default: true
      t.boolean :descriptive_links, default: true
      t.boolean :text_alternatives_enabled, default: true
      
      # Color preferences
      t.string :custom_background_color
      t.string :custom_text_color
      t.string :custom_link_color
      
      t.timestamps
    end
    
    # Language Preferences
    create_table :language_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      
      t.string :primary_language, null: false, default: 'en'
      t.string :secondary_language
      t.string :tertiary_language
      
      # Regional settings
      t.string :currency_code, default: 'USD'
      t.string :timezone
      t.string :date_format
      t.string :time_format
      
      # Translation preferences
      t.boolean :auto_translate, default: false
      t.boolean :show_original_text, default: false
      
      t.timestamps
    end
    
    add_index :language_preferences, :primary_language
    
    # Accessibility Audits
    create_table :accessibility_audits do |t|
      t.references :user, foreign_key: true, index: true
      
      t.string :page_url, null: false
      t.integer :audit_type, null: false, default: 0 # automated
      t.integer :wcag_level, default: 1 # AA
      
      # Results
      t.jsonb :results, default: {}
      t.integer :score
      t.integer :issues_found, default: 0
      t.integer :warnings_found, default: 0
      t.integer :passed_checks, default: 0
      
      # Status
      t.string :status, default: 'pending'
      t.datetime :completed_at
      
      t.timestamps
    end
    
    add_index :accessibility_audits, :page_url
    add_index :accessibility_audits, :score
    add_index :accessibility_audits, :status
    add_index :accessibility_audits, :results, using: :gin
    
    # Screen Reader Content
    create_table :screen_reader_contents do |t|
      t.references :contentable, polymorphic: true, null: false, index: true
      
      t.integer :content_type, null: false
      t.text :screen_reader_text, null: false
      t.text :long_description
      
      # ARIA attributes
      t.string :aria_label
      t.string :aria_describedby
      t.string :aria_live
      t.boolean :aria_atomic, default: false
      t.string :role
      t.string :title_text
      
      t.timestamps
    end
    
    add_index :screen_reader_contents, [:contentable_type, :contentable_id, :content_type], 
              name: 'index_screen_reader_on_contentable_and_type'
    
    # Keyboard Shortcuts
    create_table :keyboard_shortcuts do |t|
      t.references :user, foreign_key: true, index: true
      
      t.string :key_combination, null: false
      t.integer :action, null: false
      t.text :custom_action_code
      
      t.boolean :enabled, default: true
      t.boolean :is_default, default: false
      t.boolean :prevent_default, default: true
      
      t.timestamps
    end
    
    add_index :keyboard_shortcuts, [:user_id, :key_combination], unique: true
    add_index :keyboard_shortcuts, :action
    
    # Translation Cache
    create_table :translation_caches do |t|
      t.string :source_language, null: false
      t.string :target_language, null: false
      t.string :source_key, null: false
      t.text :source_text, null: false
      t.text :translated_text, null: false
      
      t.string :translation_service
      t.integer :quality_score
      t.boolean :verified, default: false
      
      t.timestamps
    end
    
    add_index :translation_caches, [:source_language, :target_language, :source_key], 
              unique: true, name: 'index_translations_on_languages_and_key'
    add_index :translation_caches, :source_key
    
    # Accessibility Feedback
    create_table :accessibility_feedbacks do |t|
      t.references :user, foreign_key: true, index: true
      
      t.string :page_url, null: false
      t.integer :feedback_type, null: false # issue, suggestion, praise
      t.text :description, null: false
      
      # Issue details
      t.string :wcag_criterion
      t.integer :severity # low, medium, high, critical
      t.string :assistive_technology # screen_reader, keyboard, voice_control, etc.
      
      # Status
      t.string :status, default: 'open' # open, in_progress, resolved, closed
      t.text :resolution_notes
      t.datetime :resolved_at
      
      t.timestamps
    end
    
    add_index :accessibility_feedbacks, :page_url
    add_index :accessibility_feedbacks, :status
    add_index :accessibility_feedbacks, :feedback_type
    
    # Add accessibility columns to users table
    add_column :users, :accessibility_needs, :jsonb, default: {}
    add_column :users, :assistive_technologies, :string, array: true, default: []
    add_column :users, :accessibility_verified, :boolean, default: false
    
    add_index :users, :accessibility_needs, using: :gin
    add_index :users, :assistive_technologies, using: :gin
  end
end

