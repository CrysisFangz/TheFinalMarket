class KeyboardShortcutManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'keyboard_shortcut_management'
  CACHE_TTL = 20.minutes

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

  def self.create_defaults_for_user(user)
    cache_key = "#{CACHE_KEY_PREFIX}:create_defaults:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          created_shortcuts = []

          DEFAULT_SHORTCUTS.each do |key_combo, action_name|
            shortcut = KeyboardShortcut.create!(
              user: user,
              key_combination: key_combo,
              action: action_name,
              enabled: true,
              is_default: true
            )

            created_shortcuts << shortcut
          end

          EventPublisher.publish('keyboard_shortcut.defaults_created', {
            user_id: user.id,
            shortcuts_count: created_shortcuts.count,
            created_at: Time.current
          })

          created_shortcuts
        end
      end
    end
  end

  def self.get_shortcuts_for_user(user)
    cache_key = "#{CACHE_KEY_PREFIX}:user_shortcuts:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          KeyboardShortcut.where(user: user, enabled: true).order(:action).to_a
        end
      end
    end
  end

  def self.find_shortcut_by_action(user, action_name)
    cache_key = "#{CACHE_KEY_PREFIX}:by_action:#{user.id}:#{action_name}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          KeyboardShortcut.find_by(user: user, action: action_name, enabled: true)
        end
      end
    end
  end

  def self.generate_javascript_mapping(user)
    cache_key = "#{CACHE_KEY_PREFIX}:js_mapping:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          shortcuts = get_shortcuts_for_user(user)

          mapping = shortcuts.map do |shortcut|
            {
              keys: shortcut.key_combination,
              action: shortcut.action,
              description: KeyboardShortcutAccessibilityService.get_description_text(shortcut.action),
              preventDefault: shortcut.prevent_default
            }
          end

          EventPublisher.publish('keyboard_shortcut.js_mapping_generated', {
            user_id: user.id,
            shortcuts_count: mapping.count,
            generated_at: Time.current
          })

          mapping
        end
      end
    end
  end

  def self.create_custom_shortcut(user, key_combination, action, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:custom:#{user.id}:#{key_combination}:#{action}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          # Check for conflicts
          existing_shortcut = KeyboardShortcut.find_by(user: user, key_combination: key_combination)
          if existing_shortcut
            raise ArgumentError, "Key combination #{key_combination} is already in use"
          end

          shortcut = KeyboardShortcut.create!(
            user: user,
            key_combination: key_combination,
            action: action,
            enabled: true,
            is_default: false,
            **attributes
          )

          EventPublisher.publish('keyboard_shortcut.custom_created', {
            shortcut_id: shortcut.id,
            user_id: user.id,
            key_combination: key_combination,
            action: action,
            created_at: Time.current
          })

          clear_user_cache(user.id)
          shortcut
        end
      end
    end
  end

  def self.update_shortcut(shortcut, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:update:#{shortcut.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          previous_enabled = shortcut.enabled

          if shortcut.update(attributes)
            EventPublisher.publish('keyboard_shortcut.updated', {
              shortcut_id: shortcut.id,
              user_id: shortcut.user_id,
              key_combination: shortcut.key_combination,
              action: shortcut.action,
              enabled: shortcut.enabled,
              previous_enabled: previous_enabled,
              updated_at: shortcut.updated_at
            })

            clear_user_cache(shortcut.user_id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.delete_shortcut(shortcut)
    cache_key = "#{CACHE_KEY_PREFIX}:delete:#{shortcut.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          user_id = shortcut.user_id

          shortcut.destroy

          EventPublisher.publish('keyboard_shortcut.deleted', {
            shortcut_id: shortcut.id,
            user_id: user_id,
            key_combination: shortcut.key_combination,
            action: shortcut.action,
            deleted_at: Time.current
          })

          clear_user_cache(user_id)
          true
        end
      end
    end
  end

  def self.check_conflicts(user, key_combination, exclude_shortcut_id = nil)
    cache_key = "#{CACHE_KEY_PREFIX}:conflicts:#{user.id}:#{key_combination}:#{exclude_shortcut_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          query = KeyboardShortcut.where(user: user, key_combination: key_combination)

          if exclude_shortcut_id
            query = query.where.not(id: exclude_shortcut_id)
          end

          conflicting_shortcuts = query.to_a

          EventPublisher.publish('keyboard_shortcut.conflicts_checked', {
            user_id: user.id,
            key_combination: key_combination,
            conflicts_count: conflicting_shortcuts.count,
            checked_at: Time.current
          })

          conflicting_shortcuts
        end
      end
    end
  end

  def self.get_shortcut_stats(user)
    cache_key = "#{CACHE_KEY_PREFIX}:stats:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          shortcuts = get_shortcuts_for_user(user)

          stats = {
            total_shortcuts: shortcuts.count,
            enabled_shortcuts: shortcuts.count { |s| s.enabled },
            disabled_shortcuts: shortcuts.count { |s| !s.enabled },
            default_shortcuts: shortcuts.count { |s| s.is_default },
            custom_shortcuts: shortcuts.count { |s| !s.is_default },
            category_distribution: categorize_shortcuts(shortcuts),
            usage_frequency: estimate_usage_frequency(shortcuts)
          }

          EventPublisher.publish('keyboard_shortcut.stats_generated', {
            user_id: user.id,
            total_shortcuts: stats[:total_shortcuts],
            enabled_shortcuts: stats[:enabled_shortcuts],
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  def self.import_shortcuts(user, shortcuts_data)
    cache_key = "#{CACHE_KEY_PREFIX}:import:#{user.id}:#{shortcuts_data.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          imported_count = 0
          errors = []

          shortcuts_data.each do |shortcut_data|
            begin
              # Check for conflicts
              conflicts = check_conflicts(user, shortcut_data[:key_combination])
              if conflicts.any?
                errors << "Key combination #{shortcut_data[:key_combination]} conflicts with existing shortcut"
                next
              end

              KeyboardShortcut.create!(
                user: user,
                key_combination: shortcut_data[:key_combination],
                action: shortcut_data[:action],
                enabled: shortcut_data[:enabled] || true,
                is_default: false,
                description: shortcut_data[:description]
              )

              imported_count += 1
            rescue => e
              errors << "Failed to import shortcut #{shortcut_data[:key_combination]}: #{e.message}"
            end
          end

          EventPublisher.publish('keyboard_shortcut.import_completed', {
            user_id: user.id,
            imported_count: imported_count,
            errors_count: errors.count,
            imported_at: Time.current
          })

          clear_user_cache(user.id)
          { imported_count: imported_count, errors: errors }
        end
      end
    end
  end

  def self.export_shortcuts(user)
    cache_key = "#{CACHE_KEY_PREFIX}:export:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('keyboard_shortcut_management') do
        with_retry do
          shortcuts = get_shortcuts_for_user(user)

          export_data = shortcuts.map do |shortcut|
            {
              key_combination: shortcut.key_combination,
              action: shortcut.action,
              enabled: shortcut.enabled,
              description: KeyboardShortcutAccessibilityService.get_description_text(shortcut.action),
              is_default: shortcut.is_default,
              created_at: shortcut.created_at
            }
          end

          EventPublisher.publish('keyboard_shortcut.export_completed', {
            user_id: user.id,
            exported_count: export_data.count,
            exported_at: Time.current
          })

          export_data
        end
      end
    end
  end

  private

  def self.categorize_shortcuts(shortcuts)
    categories = Hash.new(0)

    shortcuts.each do |shortcut|
      category = KeyboardShortcutAccessibilityService.get_shortcut_category(shortcut.action)
      categories[category] += 1
    end

    categories
  end

  def self.estimate_usage_frequency(shortcuts)
    # Estimate based on action type and user patterns
    frequency = {}

    shortcuts.each do |shortcut|
      base_frequency = case shortcut.action.to_s
                      when /navigate_/
                        'high'
                      when /skip_/, /toggle_accessibility/
                        'medium'
                      when /increase_/, /decrease_/, /toggle_/
                        'low'
                      else
                        'medium'
                      end

      frequency[shortcut.action] = base_frequency
    end

    frequency
  end

  def self.clear_user_cache(user_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:user_shortcuts:#{user_id}",
      "#{CACHE_KEY_PREFIX}:by_action:#{user_id}",
      "#{CACHE_KEY_PREFIX}:js_mapping:#{user_id}",
      "#{CACHE_KEY_PREFIX}:stats:#{user_id}",
      "#{CACHE_KEY_PREFIX}:export:#{user_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end