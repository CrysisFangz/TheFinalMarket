class KeyboardShortcutPresenter
  include CircuitBreaker
  include Retryable

  def initialize(shortcut)
    @shortcut = shortcut
  end

  def as_json(options = {})
    cache_key = "keyboard_shortcut_presenter:#{@shortcut.id}:#{@shortcut.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('keyboard_shortcut_presenter') do
        with_retry do
          {
            id: @shortcut.id,
            key_combination: @shortcut.key_combination,
            action: @shortcut.action,
            enabled: @shortcut.enabled,
            is_default: @shortcut.is_default,
            created_at: @shortcut.created_at,
            updated_at: @shortcut.updated_at,
            user: user_data,
            description: description_data,
            validation: validation_data,
            accessibility: accessibility_data,
            usage: usage_data
          }
        end
      end
    end
  end

  def to_api_response
    as_json.merge(
      metadata: {
        cache_timestamp: Time.current,
        version: '1.0'
      }
    )
  end

  def to_user_response
    as_json.merge(
      user_data: {
        can_edit: can_edit?,
        can_delete: can_delete?,
        conflicts: conflict_data,
        alternatives: alternative_suggestions
      }
    )
  end

  private

  def user_data
    return nil unless @shortcut.user

    Rails.cache.fetch("shortcut_user:#{@shortcut.user_id}", expires_in: 30.minutes) do
      with_circuit_breaker('user_data') do
        with_retry do
          {
            id: @shortcut.user.id,
            username: @shortcut.user.username,
            total_shortcuts: @shortcut.user.keyboard_shortcuts.count,
            accessibility_score: KeyboardShortcutAccessibilityService.get_accessibility_compliance_report(@shortcut.user)[:compliance_percentage]
          }
        end
      end
    end
  end

  def description_data
    Rails.cache.fetch("shortcut_description:#{@shortcut.action}", expires_in: 30.minutes) do
      with_circuit_breaker('description_data') do
        with_retry do
          {
            text: KeyboardShortcutAccessibilityService.get_description_text(@shortcut.action),
            category: KeyboardShortcutAccessibilityService.get_shortcut_category(@shortcut.action),
            is_accessibility_related: is_accessibility_action?,
            target_element: determine_target_element,
            context_help: generate_context_help
          }
        end
      end
    end
  end

  def validation_data
    Rails.cache.fetch("shortcut_validation:#{@shortcut.id}", expires_in: 15.minutes) do
      with_circuit_breaker('validation_data') do
        with_retry do
          validation = KeyboardShortcutAccessibilityService.validate_shortcut_combination(@shortcut.key_combination)

          {
            is_valid: validation[:valid],
            warnings: validation[:warnings],
            suggestions: validation[:suggestions],
            compliance_level: determine_compliance_level(validation),
            accessibility_score: calculate_accessibility_score(validation)
          }
        end
      end
    end
  end

  def accessibility_data
    Rails.cache.fetch("shortcut_accessibility:#{@shortcut.id}", expires_in: 20.minutes) do
      with_circuit_breaker('accessibility_data') do
        with_retry do
          compliance = KeyboardShortcutAccessibilityService.get_accessibility_compliance_report(@shortcut.user)

          {
            compliance_percentage: compliance[:compliance_percentage],
            wcag_level: determine_wcag_level(compliance),
            accessibility_features: extract_accessibility_features,
            user_preferences: get_user_accessibility_preferences,
            recommended_improvements: compliance[:recommendations].first(3)
          }
        end
      end
    end
  end

  def usage_data
    Rails.cache.fetch("shortcut_usage:#{@shortcut.id}", expires_in: 10.minutes) do
      with_circuit_breaker('usage_data') do
        with_retry do
          stats = KeyboardShortcutManagementService.get_shortcut_stats(@shortcut.user)

          {
            frequency_estimate: estimate_frequency,
            category_usage: stats[:category_distribution],
            customization_level: stats[:custom_shortcuts],
            user_patterns: analyze_user_patterns,
            effectiveness_score: calculate_effectiveness_score
          }
        end
      end
    end
  end

  def can_edit?
    !@shortcut.is_default || @shortcut.user_id.present?
  end

  def can_delete?
    !@shortcut.is_default
  end

  def conflict_data
    Rails.cache.fetch("shortcut_conflicts:#{@shortcut.id}", expires_in: 5.minutes) do
      with_circuit_breaker('conflict_data') do
        with_retry do
          conflicts = KeyboardShortcutManagementService.check_conflicts(@shortcut.user, @shortcut.key_combination, @shortcut.id)

          conflicts.map do |conflict|
            {
              id: conflict.id,
              action: conflict.action,
              description: KeyboardShortcutAccessibilityService.get_description_text(conflict.action),
              severity: determine_conflict_severity(conflict)
            }
          end
        end
      end
    end
  end

  def alternative_suggestions
    Rails.cache.fetch("shortcut_alternatives:#{@shortcut.id}", expires_in: 15.minutes) do
      with_circuit_breaker('alternative_suggestions') do
        with_retry do
          alternatives = generate_alternative_combinations(@shortcut.key_combination, @shortcut.action)

          alternatives.first(5).map do |alt|
            {
              combination: alt[:combination],
              accessibility_score: alt[:score],
              reason: alt[:reason]
            }
          end
        end
      end
    end
  end

  def is_accessibility_action?
    ['Accessibility', 'Skip Links'].include?(KeyboardShortcutAccessibilityService.get_shortcut_category(@shortcut.action))
  end

  def determine_target_element
    target_elements = {
      navigate_home: 'body',
      navigate_search: 'input[type="search"], .search-input',
      navigate_cart: '.cart, .shopping-cart',
      navigate_account: '.account, .user-menu',
      navigate_orders: '.orders, .order-history',
      navigate_wishlist: '.wishlist, .favorites',
      open_menu: '.menu, .navigation',
      close_menu: '.menu, .modal, .dialog',
      skip_to_content: 'main, #main, .main-content',
      skip_to_navigation: 'nav, .navigation, #navigation',
      skip_to_footer: 'footer, #footer',
      toggle_accessibility_menu: '.accessibility-menu, #accessibility',
      increase_font_size: 'body',
      decrease_font_size: 'body',
      toggle_high_contrast: 'body',
      toggle_dark_mode: 'body',
      focus_search: 'input[type="search"], .search-input',
      submit_form: 'form, .form',
      cancel_action: '.modal, .dialog, form',
      open_help: '.help, #help'
    }

    target_elements[@shortcut.action.to_sym] || 'body'
  end

  def generate_context_help
    context_help = {
      when_to_use: generate_when_to_use_text,
      related_shortcuts: find_related_shortcuts,
      browser_compatibility: check_browser_compatibility,
      mobile_support: check_mobile_support
    }

    context_help
  end

  def determine_compliance_level(validation)
    if validation[:warnings].empty?
      'full'
    elsif validation[:warnings].count <= 1
      'partial'
    else
      'low'
    end
  end

  def calculate_accessibility_score(validation)
    score = 100

    score -= validation[:warnings].count * 20
    score -= validation[:suggestions].count * 10

    # Bonus for accessibility actions
    score += 20 if is_accessibility_action?

    # Bonus for default shortcuts
    score += 10 if @shortcut.is_default

    [score, 0].max
  end

  def determine_wcag_level(compliance)
    if compliance[:wcag_compliance][:level_aaa]
      'AAA'
    elsif compliance[:wcag_compliance][:level_aa]
      'AA'
    elsif compliance[:wcag_compliance][:level_a]
      'A'
    else
      'Non-compliant'
    end
  end

  def extract_accessibility_features
    features = []

    if @shortcut.action.to_s.include?('skip')
      features << 'skip_links'
    end

    if @shortcut.action.to_s.include?('font')
      features << 'font_adjustment'
    end

    if @shortcut.action.to_s.include?('contrast')
      features << 'high_contrast'
    end

    if @shortcut.action.to_s.include?('dark')
      features << 'dark_mode'
    end

    if @shortcut.action.to_s.include?('accessibility')
      features << 'accessibility_menu'
    end

    features
  end

  def get_user_accessibility_preferences
    return {} unless @shortcut.user

    Rails.cache.fetch("user_accessibility_prefs:#{@shortcut.user_id}", expires_in: 20.minutes) do
      with_circuit_breaker('user_preferences') do
        with_retry do
          # This would integrate with user accessibility settings
          {
            prefers_reduced_motion: false,
            high_contrast_enabled: false,
            font_size_multiplier: 1.0,
            dark_mode_enabled: false,
            keyboard_navigation_preferred: true
          }
        end
      end
    end
  end

  def estimate_frequency
    frequency_scores = {
      navigate_home: 'very_high',
      navigate_search: 'high',
      navigate_cart: 'high',
      navigate_account: 'medium',
      skip_to_content: 'medium',
      toggle_accessibility_menu: 'low',
      increase_font_size: 'low',
      decrease_font_size: 'low',
      focus_search: 'high',
      submit_form: 'very_high'
    }

    frequency_scores[@shortcut.action.to_sym] || 'medium'
  end

  def analyze_user_patterns
    return {} unless @shortcut.user

    stats = KeyboardShortcutManagementService.get_shortcut_stats(@shortcut.user)

    {
      customization_level: stats[:custom_shortcuts],
      navigation_focused: stats[:category_distribution]['Navigation'].to_i > stats[:total_shortcuts] / 2,
      accessibility_focused: stats[:category_distribution]['Accessibility'].to_i > stats[:total_shortcuts] / 3,
      power_user: stats[:total_shortcuts] > 15
    }
  end

  def calculate_effectiveness_score
    score = 50 # Base score

    # Action importance
    action_scores = {
      navigate_home: 90,
      navigate_search: 85,
      navigate_cart: 80,
      skip_to_content: 75,
      focus_search: 70,
      submit_form: 95,
      toggle_accessibility_menu: 60
    }

    score += action_scores[@shortcut.action.to_sym] || 50

    # Bonus for enabled shortcuts
    score += 20 if @shortcut.enabled

    # Bonus for default shortcuts
    score += 10 if @shortcut.is_default

    # Penalty for conflicts
    score -= conflict_data.count * 15

    [score, 100].min
  end

  def determine_conflict_severity(conflict)
    if conflict.action.to_s.include?('accessibility') || @shortcut.action.to_s.include?('accessibility')
      'high'
    else
      'medium'
    end
  end

  def generate_alternative_combinations(current_combination, action)
    alternatives = []

    # Generate similar combinations
    keys = current_combination.split('+')
    modifier = keys.first

    # Try different modifiers
    alternative_modifiers = ['Alt', 'Ctrl', 'Shift'].reject { |mod| mod == modifier }

    alternative_modifiers.each do |alt_mod|
      alt_combo = "#{alt_mod}+#{keys.last}"
      validation = KeyboardShortcutAccessibilityService.validate_shortcut_combination(alt_combo)

      alternatives << {
        combination: alt_combo,
        score: calculate_accessibility_score(validation),
        reason: "Alternative modifier key (#{alt_mod})"
      }
    end

    # Try different main keys for navigation actions
    if action.to_s.include?('navigate')
      letters = ('A'..'Z').to_a
      letters.each do |letter|
        alt_combo = "Alt+#{letter}"
        validation = KeyboardShortcutAccessibilityService.validate_shortcut_combination(alt_combo)

        alternatives << {
          combination: alt_combo,
          score: calculate_accessibility_score(validation),
          reason: "Letter-based navigation shortcut"
        }
      end
    end

    alternatives.sort_by { |alt| -alt[:score] }
  end

  def generate_when_to_use_text
    when_to_use = case @shortcut.action.to_sym
                 when :navigate_home
                   'When you want to quickly return to the home page from anywhere on the site'
                 when :navigate_search
                   'When you need to search for products or content'
                 when :skip_to_content
                   'When using screen readers or keyboard navigation to skip repetitive content'
                 when :toggle_accessibility_menu
                   'When you need to access accessibility features and settings'
                 when :increase_font_size
                   'When text appears too small to read comfortably'
                 else
                   'When you need to perform this action quickly'
                 end

    when_to_use
  end

  def find_related_shortcuts
    return [] unless @shortcut.user

    related_actions = case @shortcut.action.to_sym
                     when :navigate_home
                       [:navigate_search, :navigate_cart, :navigate_account]
                     when :skip_to_content
                       [:skip_to_navigation, :skip_to_footer]
                     when :increase_font_size
                       [:decrease_font_size, :toggle_high_contrast]
                     else
                       []
                     end

    related_shortcuts = KeyboardShortcut.where(user: @shortcut.user, action: related_actions, enabled: true).pluck(:key_combination, :action)

    related_shortcuts.map do |combo, action|
      {
        combination: combo,
        action: action,
        description: KeyboardShortcutAccessibilityService.get_description_text(action)
      }
    end
  end

  def check_browser_compatibility
    {
      chrome: true,
      firefox: true,
      safari: true,
      edge: true,
      mobile_browsers: check_mobile_browser_support,
      assistive_technology: check_assistive_technology_support
    }
  end

  def check_mobile_support
    mobile_friendly_actions = [
      :navigate_home, :navigate_search, :navigate_cart, :navigate_account,
      :skip_to_content, :focus_search, :submit_form
    ]

    mobile_friendly_actions.include?(@shortcut.action.to_sym)
  end

  def check_assistive_technology_support
    at_friendly_actions = [
      :skip_to_content, :skip_to_navigation, :skip_to_footer,
      :toggle_accessibility_menu, :increase_font_size, :decrease_font_size,
      :toggle_high_contrast, :focus_search
    ]

    at_friendly_actions.include?(@shortcut.action.to_sym)
  end

  def check_mobile_browser_support
    # Most shortcuts work on mobile, but some are less useful
    mobile_unfriendly = [:toggle_dark_mode, :toggle_high_contrast]
    !mobile_unfriendly.include?(@shortcut.action.to_sym)
  end

  def check_assistive_technology_support
    at_friendly_actions = [
      :skip_to_content, :skip_to_navigation, :skip_to_footer,
      :toggle_accessibility_menu, :increase_font_size, :decrease_font_size,
      :toggle_high_contrast, :focus_search
    ]

    at_friendly_actions.include?(@shortcut.action.to_sym)
  end
end