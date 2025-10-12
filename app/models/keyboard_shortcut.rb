class KeyboardShortcut < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :key_combination, presence: true
  validates :action, presence: true
  
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
    DEFAULT_SHORTCUTS.each do |key_combo, action_name|
      create!(
        user: user,
        key_combination: key_combo,
        action: action_name,
        enabled: true,
        is_default: true
      )
    end
  end
  
  # Get all shortcuts for user
  def self.for_user(user)
    where(user: user, enabled: true).order(:action)
  end
  
  # Get shortcut by action
  def self.find_by_action(user, action_name)
    find_by(user: user, action: action_name, enabled: true)
  end
  
  # Get JavaScript mapping
  def self.javascript_mapping(user)
    shortcuts = for_user(user)
    
    shortcuts.map do |shortcut|
      {
        keys: shortcut.key_combination,
        action: shortcut.action,
        description: shortcut.description_text,
        preventDefault: shortcut.prevent_default
      }
    end
  end
  
  # Get description text
  def description_text
    case action.to_sym
    when :navigate_home
      'Navigate to home page'
    when :navigate_search
      'Navigate to search page'
    when :navigate_cart
      'Navigate to shopping cart'
    when :navigate_account
      'Navigate to account page'
    when :navigate_orders
      'Navigate to orders page'
    when :navigate_wishlist
      'Navigate to wishlist'
    when :open_menu
      'Open navigation menu'
    when :close_menu
      'Close current menu or dialog'
    when :skip_to_content
      'Skip to main content'
    when :skip_to_navigation
      'Skip to navigation'
    when :skip_to_footer
      'Skip to footer'
    when :toggle_accessibility_menu
      'Toggle accessibility menu'
    when :increase_font_size
      'Increase font size'
    when :decrease_font_size
      'Decrease font size'
    when :toggle_high_contrast
      'Toggle high contrast mode'
    when :toggle_dark_mode
      'Toggle dark mode'
    when :focus_search
      'Focus search input'
    when :submit_form
      'Submit current form'
    when :cancel_action
      'Cancel current action'
    when :open_help
      'Open help menu'
    else
      'Custom action'
    end
  end
  
  # Check if shortcut conflicts with another
  def conflicts_with?(other_shortcut)
    key_combination == other_shortcut.key_combination &&
      user_id == other_shortcut.user_id &&
      id != other_shortcut.id
  end
  
  # Get all shortcuts as help text
  def self.help_text(user)
    shortcuts = for_user(user).group_by { |s| shortcut_category(s.action) }
    
    help = {}
    shortcuts.each do |category, category_shortcuts|
      help[category] = category_shortcuts.map do |shortcut|
        {
          keys: shortcut.key_combination,
          description: shortcut.description_text
        }
      end
    end
    
    help
  end
  
  private
  
  def self.shortcut_category(action)
    case action.to_s
    when /navigate_/
      'Navigation'
    when /skip_/
      'Skip Links'
    when /toggle_/, /increase_/, /decrease_/
      'Accessibility'
    when /open_/, /close_/, /focus_/
      'Interface'
    else
      'Other'
    end
  end
end

