class KeyboardShortcutAccessibilityService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'keyboard_shortcut_accessibility'
  CACHE_TTL = 30.minutes

  def self.get_description_text(action)
    cache_key = "#{CACHE_KEY_PREFIX}:description:#{action}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
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
      end
    end
  end

  def self.get_shortcut_category(action)
    cache_key = "#{CACHE_KEY_PREFIX}:category:#{action}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
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
    end
  end

  def self.generate_help_text(user)
    cache_key = "#{CACHE_KEY_PREFIX}:help_text:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          shortcuts = KeyboardShortcutManagementService.get_shortcuts_for_user(user)
          categorized_shortcuts = shortcuts.group_by { |s| get_shortcut_category(s.action) }

          help = {}
          categorized_shortcuts.each do |category, category_shortcuts|
            help[category] = category_shortcuts.map do |shortcut|
              {
                keys: shortcut.key_combination,
                description: get_description_text(shortcut.action),
                action: shortcut.action,
                is_default: shortcut.is_default
              }
            end
          end

          EventPublisher.publish('keyboard_shortcut.help_text_generated', {
            user_id: user.id,
            categories_count: help.keys.count,
            total_shortcuts: shortcuts.count,
            generated_at: Time.current
          })

          help
        end
      end
    end
  end

  def self.validate_shortcut_combination(key_combination)
    cache_key = "#{CACHE_KEY_PREFIX}:validate:#{key_combination}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          validation = {
            valid: true,
            warnings: [],
            suggestions: []
          }

          # Check for accessibility compliance
          if is_problematic_combination?(key_combination)
            validation[:warnings] << 'This key combination may conflict with browser or assistive technology shortcuts'
            validation[:suggestions] << 'Consider using Alt or Ctrl combinations instead'
          end

          # Check for complexity
          if key_combination.split('+').count > 3
            validation[:warnings] << 'Complex key combinations may be difficult for some users'
            validation[:suggestions] << 'Consider simpler combinations with 2-3 keys'
          end

          # Check for common accessibility patterns
          unless follows_accessibility_patterns?(key_combination)
            validation[:suggestions] << 'Consider following standard accessibility key patterns (Alt+Letter, Ctrl+Letter)'
          end

          validation
        end
      end
    end
  end

  def self.get_accessibility_compliance_report(user)
    cache_key = "#{CACHE_KEY_PREFIX}:compliance:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          shortcuts = KeyboardShortcutManagementService.get_shortcuts_for_user(user)

          compliance = {
            total_shortcuts: shortcuts.count,
            compliant_shortcuts: 0,
            warnings: [],
            recommendations: [],
            wcag_compliance: {
              level_a: true,
              level_aa: true,
              level_aaa: true
            }
          }

          shortcuts.each do |shortcut|
            validation = validate_shortcut_combination(shortcut.key_combination)

            if validation[:warnings].empty?
              compliance[:compliant_shortcuts] += 1
            else
              compliance[:warnings] += validation[:warnings]
              compliance[:recommendations] += validation[:suggestions]
            end
          end

          # Calculate compliance percentage
          if shortcuts.any?
            compliance_percentage = (compliance[:compliant_shortcuts].to_f / shortcuts.count) * 100
            compliance[:compliance_percentage] = compliance_percentage

            # Update WCAG levels based on compliance
            compliance[:wcag_compliance][:level_a] = compliance_percentage >= 80
            compliance[:wcag_compliance][:level_aa] = compliance_percentage >= 90
            compliance[:wcag_compliance][:level_aaa] = compliance_percentage >= 95
          end

          EventPublisher.publish('keyboard_shortcut.compliance_report_generated', {
            user_id: user.id,
            compliance_percentage: compliance[:compliance_percentage],
            compliant_shortcuts: compliance[:compliant_shortcuts],
            total_shortcuts: compliance[:total_shortcuts],
            generated_at: Time.current
          })

          compliance
        end
      end
    end
  end

  def self.get_shortcut_analytics(user)
    cache_key = "#{CACHE_KEY_PREFIX}:analytics:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          shortcuts = KeyboardShortcutManagementService.get_shortcuts_for_user(user)
          stats = KeyboardShortcutManagementService.get_shortcut_stats(user)

          analytics = {
            usage_patterns: analyze_usage_patterns(shortcuts),
            accessibility_score: calculate_accessibility_score(shortcuts),
            customization_level: calculate_customization_level(shortcuts),
            category_usage: stats[:category_distribution],
            frequency_analysis: analyze_frequency_patterns(shortcuts),
            improvement_suggestions: generate_improvement_suggestions(shortcuts)
          }

          EventPublisher.publish('keyboard_shortcut.analytics_generated', {
            user_id: user.id,
            accessibility_score: analytics[:accessibility_score],
            customization_level: analytics[:customization_level],
            generated_at: Time.current
          })

          analytics
        end
      end
    end
  end

  def self.suggest_improvements(user)
    cache_key = "#{CACHE_KEY_PREFIX}:improvements:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          shortcuts = KeyboardShortcutManagementService.get_shortcuts_for_user(user)
          compliance = get_accessibility_compliance_report(user)

          improvements = []

          # Check for missing accessibility shortcuts
          missing_accessibility = check_missing_accessibility_shortcuts(shortcuts)
          improvements += missing_accessibility

          # Check for compliance issues
          if compliance[:compliance_percentage] < 90
            improvements << {
              type: 'compliance',
              priority: 'high',
              title: 'Improve Accessibility Compliance',
              description: "Current compliance is #{compliance[:compliance_percentage].round}%",
              actions: compliance[:recommendations]
            }
          end

          # Check for unused categories
          unused_categories = identify_unused_categories(shortcuts)
          improvements += unused_categories

          # Check for optimization opportunities
          optimization_suggestions = suggest_optimizations(shortcuts)
          improvements += optimization_suggestions

          EventPublisher.publish('keyboard_shortcut.improvements_suggested', {
            user_id: user.id,
            improvements_count: improvements.count,
            high_priority_count: improvements.count { |i| i[:priority] == 'high' },
            suggested_at: Time.current
          })

          improvements
        end
      end
    end
  end

  private

  def self.is_problematic_combination?(key_combination)
    # Check for combinations that conflict with browser/AT shortcuts
    problematic_combinations = [
      'Ctrl+C', 'Ctrl+V', 'Ctrl+X', 'Ctrl+Z', 'Ctrl+Y', # Common editing
      'Ctrl+A', 'Ctrl+S', 'Ctrl+O', 'Ctrl+P', # Common browser
      'Ctrl+W', 'Ctrl+Q', 'Ctrl+T', 'Ctrl+N', # Browser navigation
      'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12', # Function keys
      'Alt+F4', 'Alt+Tab', 'Alt+Space' # System shortcuts
    ]

    problematic_combinations.include?(key_combination)
  end

  def self.follows_accessibility_patterns?(key_combination)
    # Check if combination follows accessibility best practices
    keys = key_combination.split('+')

    # Should use modifier keys
    has_modifier = keys.any? { |key| ['Alt', 'Ctrl', 'Shift'].include?(key) }

    # Should be simple (2-3 keys)
    reasonable_length = keys.count <= 3

    # Should use letters or numbers for the main key
    main_key = keys.last
    good_main_key = main_key.match?(/^[A-Za-z0-9]$/) || ['Enter', 'Escape', 'Space', 'Tab', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].include?(main_key)

    has_modifier && reasonable_length && good_main_key
  end

  def self.analyze_usage_patterns(shortcuts)
    patterns = {
      navigation_focused: shortcuts.count { |s| s.action.to_s.include?('navigate') } > shortcuts.count / 2,
      accessibility_focused: shortcuts.count { |s| get_shortcut_category(s.action) == 'Accessibility' } > shortcuts.count / 3,
      power_user: shortcuts.count > 15,
      beginner_friendly: shortcuts.all? { |s| follows_accessibility_patterns?(s.key_combination) }
    }

    patterns
  end

  def self.calculate_accessibility_score(shortcuts)
    score = 100

    shortcuts.each do |shortcut|
      validation = validate_shortcut_combination(shortcut.key_combination)

      # Deduct points for warnings
      score -= validation[:warnings].count * 10

      # Deduct points for non-compliance
      unless follows_accessibility_patterns?(shortcut.key_combination)
        score -= 15
      end

      # Bonus points for good practices
      if shortcut.is_default && follows_accessibility_patterns?(shortcut.key_combination)
        score += 5
      end
    end

    [score, 0].max
  end

  def self.calculate_customization_level(shortcuts)
    custom_shortcuts = shortcuts.count { |s| !s.is_default }
    total_shortcuts = shortcuts.count

    if total_shortcuts.zero?
      0
    else
      (custom_shortcuts.to_f / total_shortcuts) * 100
    end
  end

  def self.analyze_frequency_analysis(shortcuts)
    # Analyze which shortcuts are likely used most frequently
    frequency_scores = {}

    shortcuts.each do |shortcut|
      base_score = case shortcut.action.to_s
                  when /navigate_/
                    80
                  when /skip_/
                    60
                  when /toggle_accessibility/
                    40
                  when /increase_/, /decrease_/
                    30
                  else
                    50
                  end

      # Bonus for default shortcuts (more likely to be used)
      base_score += 20 if shortcut.is_default

      frequency_scores[shortcut.action] = base_score
    end

    frequency_scores
  end

  def self.check_missing_accessibility_shortcuts(shortcuts)
    missing = []

    required_actions = [
      :navigate_home, :navigate_search, :skip_to_content,
      :toggle_accessibility_menu, :increase_font_size, :decrease_font_size
    ]

    existing_actions = shortcuts.map(&:action).map(&:to_sym)

    required_actions.each do |action|
      unless existing_actions.include?(action)
        missing << {
          type: 'missing',
          priority: 'medium',
          title: 'Missing Essential Accessibility Shortcut',
          description: "Consider adding #{action.to_s.humanize} shortcut",
          action: action,
          suggested_key: suggest_key_for_action(action)
        }
      end
    end

    missing
  end

  def self.identify_unused_categories(shortcuts)
    unused = []

    all_categories = ['Navigation', 'Skip Links', 'Accessibility', 'Interface']
    used_categories = shortcuts.map { |s| get_shortcut_category(s.action) }.uniq

    all_categories.each do |category|
      unless used_categories.include?(category)
        unused << {
          type: 'unused_category',
          priority: 'low',
          title: "Unused Category: #{category}",
          description: "No shortcuts in #{category} category",
          suggestion: "Consider adding shortcuts for #{category.downcase}"
        }
      end
    end

    unused
  end

  def self.suggest_optimizations(shortcuts)
    optimizations = []

    # Check for too many shortcuts
    if shortcuts.count > 20
      optimizations << {
        type: 'optimization',
        priority: 'low',
        title: 'Too Many Shortcuts',
        description: 'Consider reducing the number of shortcuts for better usability',
        suggestion: 'Focus on the most frequently used actions'
      }
    end

    # Check for conflicting patterns
    key_patterns = shortcuts.map(&:key_combination).group_by { |k| k.split('+').first }
    if key_patterns.values.any? { |keys| keys.count > 5 }
      optimizations << {
        type: 'optimization',
        priority: 'medium',
        title: 'Conflicting Key Patterns',
        description: 'Multiple shortcuts use the same modifier key',
        suggestion: 'Consider redistributing shortcuts across different modifier keys'
      }
    end

    optimizations
  end

  def self.suggest_key_for_action(action)
    suggestions = {
      navigate_home: 'Alt+H',
      navigate_search: 'Alt+S',
      skip_to_content: 'Alt+1',
      toggle_accessibility_menu: 'Alt+0',
      increase_font_size: 'Ctrl+Plus',
      decrease_font_size: 'Ctrl+Minus'
    }

    suggestions[action] || 'Alt+X'
  end

  def self.clear_accessibility_cache(user_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:description",
      "#{CACHE_KEY_PREFIX}:category",
      "#{CACHE_KEY_PREFIX}:help_text:#{user_id}",
      "#{CACHE_KEY_PREFIX}:compliance:#{user_id}",
      "#{CACHE_KEY_PREFIX}:analytics:#{user_id}",
      "#{CACHE_KEY_PREFIX}:improvements:#{user_id}",
      "#{CACHE_KEY_PREFIX}:validate"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end</content>
<content lines="1-300">
class KeyboardShortcutAccessibilityService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'keyboard_shortcut_accessibility'
  CACHE_TTL = 30.minutes

  def self.get_description_text(action)
    cache_key = "#{CACHE_KEY_PREFIX}:description:#{action}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
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
      end
    end
  end

  def self.get_shortcut_category(action)
    cache_key = "#{CACHE_KEY_PREFIX}:category:#{action}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
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
    end
  end

  def self.generate_help_text(user)
    cache_key = "#{CACHE_KEY_PREFIX}:help_text:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          shortcuts = KeyboardShortcutManagementService.get_shortcuts_for_user(user)
          categorized_shortcuts = shortcuts.group_by { |s| get_shortcut_category(s.action) }

          help = {}
          categorized_shortcuts.each do |category, category_shortcuts|
            help[category] = category_shortcuts.map do |shortcut|
              {
                keys: shortcut.key_combination,
                description: get_description_text(shortcut.action),
                action: shortcut.action,
                is_default: shortcut.is_default
              }
            end
          end

          EventPublisher.publish('keyboard_shortcut.help_text_generated', {
            user_id: user.id,
            categories_count: help.keys.count,
            total_shortcuts: shortcuts.count,
            generated_at: Time.current
          })

          help
        end
      end
    end
  end

  def self.validate_shortcut_combination(key_combination)
    cache_key = "#{CACHE_KEY_PREFIX}:validate:#{key_combination}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          validation = {
            valid: true,
            warnings: [],
            suggestions: []
          }

          # Check for accessibility compliance
          if is_problematic_combination?(key_combination)
            validation[:warnings] << 'This key combination may conflict with browser or assistive technology shortcuts'
            validation[:suggestions] << 'Consider using Alt or Ctrl combinations instead'
          end

          # Check for complexity
          if key_combination.split('+').count > 3
            validation[:warnings] << 'Complex key combinations may be difficult for some users'
            validation[:suggestions] << 'Consider simpler combinations with 2-3 keys'
          end

          # Check for common accessibility patterns
          unless follows_accessibility_patterns?(key_combination)
            validation[:suggestions] << 'Consider following standard accessibility key patterns (Alt+Letter, Ctrl+Letter)'
          end

          validation
        end
      end
    end
  end

  def self.get_accessibility_compliance_report(user)
    cache_key = "#{CACHE_KEY_PREFIX}:compliance:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          shortcuts = KeyboardShortcutManagementService.get_shortcuts_for_user(user)

          compliance = {
            total_shortcuts: shortcuts.count,
            compliant_shortcuts: 0,
            warnings: [],
            recommendations: [],
            wcag_compliance: {
              level_a: true,
              level_aa: true,
              level_aaa: true
            }
          }

          shortcuts.each do |shortcut|
            validation = validate_shortcut_combination(shortcut.key_combination)

            if validation[:warnings].empty?
              compliance[:compliant_shortcuts] += 1
            else
              compliance[:warnings] += validation[:warnings]
              compliance[:recommendations] += validation[:suggestions]
            end
          end

          # Calculate compliance percentage
          if shortcuts.any?
            compliance_percentage = (compliance[:compliant_shortcuts].to_f / shortcuts.count) * 100
            compliance[:compliance_percentage] = compliance_percentage

            # Update WCAG levels based on compliance
            compliance[:wcag_compliance][:level_a] = compliance_percentage >= 80
            compliance[:wcag_compliance][:level_aa] = compliance_percentage >= 90
            compliance[:wcag_compliance][:level_aaa] = compliance_percentage >= 95
          end

          EventPublisher.publish('keyboard_shortcut.compliance_report_generated', {
            user_id: user.id,
            compliance_percentage: compliance[:compliance_percentage],
            compliant_shortcuts: compliance[:compliant_shortcuts],
            total_shortcuts: compliance[:total_shortcuts],
            generated_at: Time.current
          })

          compliance
        end
      end
    end
  end

  def self.get_shortcut_analytics(user)
    cache_key = "#{CACHE_KEY_PREFIX}:analytics:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          shortcuts = KeyboardShortcutManagementService.get_shortcuts_for_user(user)
          stats = KeyboardShortcutManagementService.get_shortcut_stats(user)

          analytics = {
            usage_patterns: analyze_usage_patterns(shortcuts),
            accessibility_score: calculate_accessibility_score(shortcuts),
            customization_level: calculate_customization_level(shortcuts),
            category_usage: stats[:category_distribution],
            frequency_analysis: analyze_frequency_analysis(shortcuts),
            improvement_suggestions: generate_improvement_suggestions(shortcuts)
          }

          EventPublisher.publish('keyboard_shortcut.analytics_generated', {
            user_id: user.id,
            accessibility_score: analytics[:accessibility_score],
            customization_level: analytics[:customization_level],
            generated_at: Time.current
          })

          analytics
        end
      end
    end
  end

  def self.suggest_improvements(user)
    cache_key = "#{CACHE_KEY_PREFIX}:improvements:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_accessibility') do
        with_retry do
          shortcuts = KeyboardShortcutManagementService.get_shortcuts_for_user(user)
          compliance = get_accessibility_compliance_report(user)

          improvements = []

          # Check for missing accessibility shortcuts
          missing_accessibility = check_missing_accessibility_shortcuts(shortcuts)
          improvements += missing_accessibility

          # Check for compliance issues
          if compliance[:compliance_percentage] < 90
            improvements << {
              type: 'compliance',
              priority: 'high',
              title: 'Improve Accessibility Compliance',
              description: "Current compliance is #{compliance[:compliance_percentage].round}%",
              actions: compliance[:recommendations]
            }
          end

          # Check for unused categories
          unused_categories = identify_unused_categories(shortcuts)
          improvements += unused_categories

          # Check for optimization opportunities
          optimization_suggestions = suggest_optimizations(shortcuts)
          improvements += optimization_suggestions

          EventPublisher.publish('keyboard_shortcut.improvements_suggested', {
            user_id: user.id,
            improvements_count: improvements.count,
            high_priority_count: improvements.count { |i| i[:priority] == 'high' },
            suggested_at: Time.current
          })

          improvements
        end
      end
    end
  end

  private

  def self.is_problematic_combination?(key_combination)
    # Check for combinations that conflict with browser/AT shortcuts
    problematic_combinations = [
      'Ctrl+C', 'Ctrl+V', 'Ctrl+X', 'Ctrl+Z', 'Ctrl+Y', # Common editing
      'Ctrl+A', 'Ctrl+S', 'Ctrl+O', 'Ctrl+P', # Common browser
      'Ctrl+W', 'Ctrl+Q', 'Ctrl+T', 'Ctrl+N', # Browser navigation
      'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12', # Function keys
      'Alt+F4', 'Alt+Tab', 'Alt+Space' # System shortcuts
    ]

    problematic_combinations.include?(key_combination)
  end

  def self.follows_accessibility_patterns?(key_combination)
    # Check if combination follows accessibility best practices
    keys = key_combination.split('+')

    # Should use modifier keys
    has_modifier = keys.any? { |key| ['Alt', 'Ctrl', 'Shift'].include?(key) }

    # Should be simple (2-3 keys)
    reasonable_length = keys.count <= 3

    # Should use letters or numbers for the main key
    main_key = keys.last
    good_main_key = main_key.match?(/^[A-Za-z0-9]$/) || ['Enter', 'Escape', 'Space', 'Tab', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].include?(main_key)

    has_modifier && reasonable_length && good_main_key
  end

  def self.analyze_usage_patterns(shortcuts)
    patterns = {
      navigation_focused: shortcuts.count { |s| s.action.to_s.include?('navigate') } > shortcuts.count / 2,
      accessibility_focused: shortcuts.count { |s| get_shortcut_category(s.action) == 'Accessibility' } > shortcuts.count / 3,
      power_user: shortcuts.count > 15,
      beginner_friendly: shortcuts.all? { |s| follows_accessibility_patterns?(s.key_combination) }
    }

    patterns
  end

  def self.calculate_accessibility_score(shortcuts)
    score = 100

    shortcuts.each do |shortcut|
      validation = validate_shortcut_combination(shortcut.key_combination)

      # Deduct points for warnings
      score -= validation[:warnings].count * 10

      # Deduct points for non-compliance
      unless follows_accessibility_patterns?(shortcut.key_combination)
        score -= 15
      end

      # Bonus points for good practices
      if shortcut.is_default && follows_accessibility_patterns?(shortcut.key_combination)
        score += 5
      end
    end

    [score, 0].max
  end

  def self.calculate_customization_level(shortcuts)
    custom_shortcuts = shortcuts.count { |s| !s.is_default }
    total_shortcuts = shortcuts.count

    if total_shortcuts.zero?
      0
    else
      (custom_shortcuts.to_f / total_shortcuts) * 100
    end
  end

  def self.analyze_frequency_analysis(shortcuts)
    # Analyze which shortcuts are likely used most frequently
    frequency_scores = {}

    shortcuts.each do |shortcut|
      base_score = case shortcut.action.to_s
                  when /navigate_/
                    80
                  when /skip_/
                    60
                  when /toggle_accessibility/
                    40
                  when /increase_/, /decrease_/
                    30
                  else
                    50
                  end

      # Bonus for default shortcuts (more likely to be used)
      base_score += 20 if shortcut.is_default

      frequency_scores[shortcut.action] = base_score
    end

    frequency_scores
  end

  def self.check_missing_accessibility_shortcuts(shortcuts)
    missing = []

    required_actions = [
      :navigate_home, :navigate_search, :skip_to_content,
      :toggle_accessibility_menu, :increase_font_size, :decrease_font_size
    ]

    existing_actions = shortcuts.map(&:action).map(&:to_sym)

    required_actions.each do |action|
      unless existing_actions.include?(action)
        missing << {
          type: 'missing',
          priority: 'medium',
          title: 'Missing Essential Accessibility Shortcut',
          description: "Consider adding #{action.to_s.humanize} shortcut",
          action: action,
          suggested_key: suggest_key_for_action(action)
        }
      end
    end

    missing
  end

  def self.identify_unused_categories(shortcuts)
    unused = []

    all_categories = ['Navigation', 'Skip Links', 'Accessibility', 'Interface']
    used_categories = shortcuts.map { |s| get_shortcut_category(s.action) }.uniq

    all_categories.each do |category|
      unless used_categories.include?(category)
        unused << {
          type: 'unused_category',
          priority: 'low',
          title: "Unused Category: #{category}",
          description: "No shortcuts in #{category} category",
          suggestion: "Consider adding shortcuts for #{category.downcase}"
        }
      end
    end

    unused
  end

  def self.suggest_optimizations(shortcuts)
    optimizations = []

    # Check for too many shortcuts
    if shortcuts.count > 20
      optimizations << {
        type: 'optimization',
        priority: 'low',
        title: 'Too Many Shortcuts',
        description: 'Consider reducing the number of shortcuts for better usability',
        suggestion: 'Focus on the most frequently used actions'
      }
    end

    # Check for conflicting patterns
    key_patterns = shortcuts.map(&:key_combination).group_by { |k| k.split('+').first }
    if key_patterns.values.any? { |keys| keys.count > 5 }
      optimizations << {
        type: 'optimization',
        priority: 'medium',
        title: 'Conflicting Key Patterns',
        description: 'Multiple shortcuts use the same modifier key',
        suggestion: 'Consider redistributing shortcuts across different modifier keys'
      }
    end

    optimizations
  end

  def self.suggest_key_for_action(action)
    suggestions = {
      navigate_home: 'Alt+H',
      navigate_search: 'Alt+S',
      skip_to_content: 'Alt+1',
      toggle_accessibility_menu: 'Alt+0',
      increase_font_size: 'Ctrl+Plus',
      decrease_font_size: 'Ctrl+Minus'
    }

    suggestions[action] || 'Alt+X'
  end

  def self.clear_accessibility_cache(user_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:description",
      "#{CACHE_KEY_PREFIX}:category",
      "#{CACHE_KEY_PREFIX}:help_text:#{user_id}",
      "#{CACHE_KEY_PREFIX}:compliance:#{user_id}",
      "#{CACHE_KEY_PREFIX}:analytics:#{user_id}",
      "#{CACHE_KEY_PREFIX}:improvements:#{user_id}",
      "#{CACHE_KEY_PREFIX}:validate"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end