class KeyboardShortcut < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :user, optional: true

  validates :key_combination, presence: true
  validates :action, presence: true

  # Caching
  after_create :clear_shortcut_cache
  after_update :clear_shortcut_cache
  after_destroy :clear_shortcut_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event
  
  enum action: {
    navigate_home: 0,
    navigate_search: 1,
    navigate_cart: 2,
    navigate_account: 3,
    navigate_orders: 4,
    navigate_wishlist: 5,
    open_menu: 6,
    close_menu: 7,
    skip_to_content: 8,
    skip_to_navigation: 9,
    skip_to_footer: 10,
    toggle_accessibility_menu: 11,
    increase_font_size: 12,
    decrease_font_size: 13,
    toggle_high_contrast: 14,
    toggle_dark_mode: 15,
    focus_search: 16,
    submit_form: 17,
    cancel_action: 18,
    open_help: 19
  }
  
  # Default keyboard shortcuts
  DEFAULT_SHORTCUTS = {
    'Alt+H' => :navigate_home,
    'Alt+S' => :navigate_search,
    'Alt+C' => :navigate_cart,
    'Alt+A' => :navigate_account,
    'Alt+O' => :navigate_orders,
    'Alt+W' => :navigate_wishlist,
    'Alt+M' => :open_menu,
    'Escape' => :close_menu,
    'Alt+1' => :skip_to_content,
    'Alt+2' => :skip_to_navigation,
    'Alt+3' => :skip_to_footer,
    'Alt+0' => :toggle_accessibility_menu,
    'Ctrl+Plus' => :increase_font_size,
    'Ctrl+Minus' => :decrease_font_size,
    'Alt+K' => :toggle_high_contrast,
    'Alt+D' => :toggle_dark_mode,
    '/' => :focus_search,
    'Enter' => :submit_form,
    'Escape' => :cancel_action,
    'Alt+?' => :open_help
  }.freeze
  
  # Create default shortcuts for user
  def self.create_defaults_for_user(user)
    KeyboardShortcutManagementService.create_defaults_for_user(user)
  end

  # Get all shortcuts for user
  def self.for_user(user)
    KeyboardShortcutManagementService.get_shortcuts_for_user(user)
  end

  # Get shortcut by action
  def self.find_by_action(user, action_name)
    KeyboardShortcutManagementService.find_shortcut_by_action(user, action_name)
  end

  # Get JavaScript mapping
  def self.javascript_mapping(user)
    KeyboardShortcutManagementService.generate_javascript_mapping(user)
  end

  # Get description text
  def description_text
    KeyboardShortcutAccessibilityService.get_description_text(action)
  end

  # Check if shortcut conflicts with another
  def conflicts_with?(other_shortcut)
    key_combination == other_shortcut.key_combination &&
      user_id == other_shortcut.user_id &&
      id != other_shortcut.id
  end

  # Get all shortcuts as help text
  def self.help_text(user)
    KeyboardShortcutAccessibilityService.generate_help_text(user)
  end
  
  def self.cached_find(id)
    Rails.cache.fetch("keyboard_shortcut:#{id}", expires_in: 30.minutes) do
      find_by(id: id)
    end
  end

  def self.cached_for_user(user_id)
    user = User.find(user_id)
    KeyboardShortcutManagementService.get_shortcuts_for_user(user)
  end

  def self.cached_by_action(user_id, action)
    user = User.find(user_id)
    KeyboardShortcutManagementService.find_shortcut_by_action(user, action)
  end

  def self.get_stats(user_id)
    user = User.find(user_id)
    KeyboardShortcutManagementService.get_shortcut_stats(user)
  end

  def self.get_compliance_report(user_id)
    user = User.find(user_id)
    KeyboardShortcutAccessibilityService.get_accessibility_compliance_report(user)
  end

  def self.get_analytics(user_id)
    user = User.find(user_id)
    KeyboardShortcutAccessibilityService.get_shortcut_analytics(user)
  end

  def self.suggest_improvements(user_id)
    user = User.find(user_id)
    KeyboardShortcutAccessibilityService.suggest_improvements(user)
  end

  def self.check_conflicts(user_id, key_combination, exclude_shortcut_id = nil)
    user = User.find(user_id)
    KeyboardShortcutManagementService.check_conflicts(user, key_combination, exclude_shortcut_id)
  end

  def self.import_shortcuts(user_id, shortcuts_data)
    user = User.find(user_id)
    KeyboardShortcutManagementService.import_shortcuts(user, shortcuts_data)
  end

  def self.export_shortcuts(user_id)
    user = User.find(user_id)
    KeyboardShortcutManagementService.export_shortcuts(user)
  end

  def self.validate_combination(key_combination)
    KeyboardShortcutAccessibilityService.validate_shortcut_combination(key_combination)
  end

  def presenter
    @presenter ||= KeyboardShortcutPresenter.new(self)
  end

  private

  def clear_shortcut_cache
    if user_id
      KeyboardShortcutManagementService.clear_user_cache(user_id)
      KeyboardShortcutAccessibilityService.clear_accessibility_cache(user_id)
    end

    # Clear related caches
    Rails.cache.delete("keyboard_shortcut:#{id}")
    Rails.cache.delete("shortcuts:user:#{user_id}")
  end

  def publish_created_event
    EventPublisher.publish('keyboard_shortcut.created', {
      shortcut_id: id,
      user_id: user_id,
      key_combination: key_combination,
      action: action,
      enabled: enabled,
      is_default: is_default,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('keyboard_shortcut.updated', {
      shortcut_id: id,
      user_id: user_id,
      key_combination: key_combination,
      action: action,
      enabled: enabled,
      is_default: is_default,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('keyboard_shortcut.destroyed', {
      shortcut_id: id,
      user_id: user_id,
      key_combination: key_combination,
      action: action,
      enabled: enabled,
      is_default: is_default
    })
  end
end

