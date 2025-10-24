class LanguagePreferenceManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'language_preference_management'
  CACHE_TTL = 20.minutes

  SUPPORTED_LANGUAGES = {
    'en' => { name: 'English', native: 'English', rtl: false },
    'es' => { name: 'Spanish', native: 'Español', rtl: false },
    'fr' => { name: 'French', native: 'Français', rtl: false },
    'de' => { name: 'German', native: 'Deutsch', rtl: false },
    'it' => { name: 'Italian', native: 'Italiano', rtl: false },
    'pt' => { name: 'Portuguese', native: 'Português', rtl: false },
    'ru' => { name: 'Russian', native: 'Русский', rtl: false },
    'zh' => { name: 'Chinese', native: '中文', rtl: false },
    'ja' => { name: 'Japanese', native: '日本語', rtl: false },
    'ko' => { name: 'Korean', native: '한국어', rtl: false },
    'ar' => { name: 'Arabic', native: 'العربية', rtl: true },
    'he' => { name: 'Hebrew', native: 'עברית', rtl: true },
    'hi' => { name: 'Hindi', native: 'हिन्दी', rtl: false },
    'bn' => { name: 'Bengali', native: 'বাংলা', rtl: false },
    'pa' => { name: 'Punjabi', native: 'ਪੰਜਾਬੀ', rtl: false },
    'te' => { name: 'Telugu', native: 'తెలుగు', rtl: false },
    'mr' => { name: 'Marathi', native: 'मराठी', rtl: false },
    'ta' => { name: 'Tamil', native: 'தமிழ்', rtl: false },
    'ur' => { name: 'Urdu', native: 'اردو', rtl: true },
    'tr' => { name: 'Turkish', native: 'Türkçe', rtl: false },
    'vi' => { name: 'Vietnamese', native: 'Tiếng Việt', rtl: false },
    'th' => { name: 'Thai', native: 'ไทย', rtl: false },
    'nl' => { name: 'Dutch', native: 'Nederlands', rtl: false },
    'pl' => { name: 'Polish', native: 'Polski', rtl: false },
    'sv' => { name: 'Swedish', native: 'Svenska', rtl: false },
    'no' => { name: 'Norwegian', native: 'Norsk', rtl: false },
    'da' => { name: 'Danish', native: 'Dansk', rtl: false },
    'fi' => { name: 'Finnish', native: 'Suomi', rtl: false },
    'cs' => { name: 'Czech', native: 'Čeština', rtl: false },
    'hu' => { name: 'Hungarian', native: 'Magyar', rtl: false },
    'ro' => { name: 'Romanian', native: 'Română', rtl: false },
    'uk' => { name: 'Ukrainian', native: 'Українська', rtl: false },
    'el' => { name: 'Greek', native: 'Ελληνικά', rtl: false },
    'id' => { name: 'Indonesian', native: 'Bahasa Indonesia', rtl: false },
    'ms' => { name: 'Malay', native: 'Bahasa Melayu', rtl: false },
    'fa' => { name: 'Persian', native: 'فارسی', rtl: true },
    'sw' => { name: 'Swahili', native: 'Kiswahili', rtl: false },
    'af' => { name: 'Afrikaans', native: 'Afrikaans', rtl: false },
    'sq' => { name: 'Albanian', native: 'Shqip', rtl: false },
    'am' => { name: 'Amharic', native: 'አማርኛ', rtl: false },
    'hy' => { name: 'Armenian', native: 'Հայերեն', rtl: false },
    'az' => { name: 'Azerbaijani', native: 'Azərbaycan', rtl: false },
    'eu' => { name: 'Basque', native: 'Euskara', rtl: false },
    'be' => { name: 'Belarusian', native: 'Беларуская', rtl: false },
    'bs' => { name: 'Bosnian', native: 'Bosanski', rtl: false },
    'bg' => { name: 'Bulgarian', native: 'Български', rtl: false },
    'ca' => { name: 'Catalan', native: 'Català', rtl: false },
    'hr' => { name: 'Croatian', native: 'Hrvatski', rtl: false },
    'et' => { name: 'Estonian', native: 'Eesti', rtl: false },
    'tl' => { name: 'Filipino', native: 'Filipino', rtl: false },
    'ka' => { name: 'Georgian', native: 'ქართული', rtl: false }
  }.freeze

  def self.get_supported_languages
    cache_key = "#{CACHE_KEY_PREFIX}:supported_languages"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          SUPPORTED_LANGUAGES
        end
      end
    end
  end

  def self.detect_language_from_browser(accept_language_header)
    cache_key = "#{CACHE_KEY_PREFIX}:detect_browser:#{accept_language_header}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          return 'en' unless accept_language_header

          # Parse Accept-Language header
          languages = accept_language_header.split(',').map do |lang|
            parts = lang.split(';')
            code = parts[0].strip.split('-').first
            quality = parts[1] ? parts[1].split('=')[1].to_f : 1.0
            [code, quality]
          end.sort_by { |_, q| -q }

          # Find first supported language
          languages.each do |code, _|
            return code if SUPPORTED_LANGUAGES.key?(code)
          end

          'en' # Default to English
        end
      end
    end
  end

  def self.create_or_update_preference(user, primary_language, secondary_language = nil, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create_update:#{user.id}:#{primary_language}:#{secondary_language}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          preference = LanguagePreference.find_or_initialize_by(user: user)

          if preference.update(
            primary_language: primary_language,
            secondary_language: secondary_language,
            **attributes
          )
            EventPublisher.publish('language_preference.updated', {
              preference_id: preference.id,
              user_id: user.id,
              primary_language: primary_language,
              secondary_language: secondary_language,
              updated_at: preference.updated_at
            })

            clear_user_cache(user.id)
            preference
          else
            false
          end
        end
      end
    end
  end

  def self.get_user_preference(user_id)
    cache_key = "#{CACHE_KEY_PREFIX}:user_preference:#{user_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          LanguagePreference.find_by(user_id: user_id)
        end
      end
    end
  end

  def self.get_fallback_languages(preference)
    cache_key = "#{CACHE_KEY_PREFIX}:fallback:#{preference.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          [preference.primary_language, preference.secondary_language, 'en'].compact.uniq
        end
      end
    end
  end

  def self.get_language_info(language_code)
    cache_key = "#{CACHE_KEY_PREFIX}:language_info:#{language_code}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          SUPPORTED_LANGUAGES[language_code] || SUPPORTED_LANGUAGES['en']
        end
      end
    end
  end

  def self.get_translation_coverage(preference)
    cache_key = "#{CACHE_KEY_PREFIX}:translation_coverage:#{preference.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          # This would integrate with translation service
          # For now, return mock data
          coverage = {
            preference.primary_language => 100,
            preference.secondary_language => 95,
            'en' => 100
          }.compact

          EventPublisher.publish('language_preference.translation_coverage_calculated', {
            preference_id: preference.id,
            user_id: preference.user_id,
            primary_language: preference.primary_language,
            secondary_language: preference.secondary_language,
            coverage: coverage,
            calculated_at: Time.current
          })

          coverage
        end
      end
    end
  end

  def self.get_regional_settings(preference)
    cache_key = "#{CACHE_KEY_PREFIX}:regional_settings:#{preference.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          settings = LocalizationService.get_regional_settings(preference)

          EventPublisher.publish('language_preference.regional_settings_generated', {
            preference_id: preference.id,
            user_id: preference.user_id,
            primary_language: preference.primary_language,
            settings: settings,
            generated_at: Time.current
          })

          settings
        end
      end
    end
  end

  def self.get_language_stats
    cache_key = "#{CACHE_KEY_PREFIX}:language_stats"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          preferences = LanguagePreference.all

          stats = {
            total_users: preferences.count,
            language_distribution: preferences.group(:primary_language).count,
            rtl_languages_count: preferences.count { |p| SUPPORTED_LANGUAGES[p.primary_language][:rtl] },
            top_languages: preferences.group(:primary_language).count.sort_by { |_, count| -count }.first(10).to_h,
            users_with_secondary: preferences.where.not(secondary_language: nil).count,
            default_language_users: preferences.where(primary_language: 'en').count
          }

          EventPublisher.publish('language_preference.stats_generated', {
            total_users: stats[:total_users],
            top_languages_count: stats[:top_languages].count,
            rtl_languages_percentage: (stats[:rtl_languages_count].to_f / stats[:total_users]) * 100,
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  def self.migrate_user_preferences(old_preferences_data)
    cache_key = "#{CACHE_KEY_PREFIX}:migrate:#{old_preferences_data.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          migrated_count = 0
          errors = []

          old_preferences_data.each do |user_id, language_data|
            begin
              user = User.find(user_id)
              create_or_update_preference(user, language_data['primary'], language_data['secondary'])
              migrated_count += 1
            rescue => e
              errors << "Failed to migrate user #{user_id}: #{e.message}"
            end
          end

          EventPublisher.publish('language_preference.migration_completed', {
            migrated_count: migrated_count,
            errors_count: errors.count,
            migration_date: Time.current
          })

          { migrated_count: migrated_count, errors: errors }
        end
      end
    end
  end

  private

  def self.clear_user_cache(user_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:user_preference:#{user_id}",
      "#{CACHE_KEY_PREFIX}:fallback:#{user_id}",
      "#{CACHE_KEY_PREFIX}:regional_settings:#{user_id}",
      "#{CACHE_KEY_PREFIX}:translation_coverage:#{user_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end</content>
<content lines="1-200">
class LanguagePreferenceManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'language_preference_management'
  CACHE_TTL = 20.minutes

  SUPPORTED_LANGUAGES = {
    'en' => { name: 'English', native: 'English', rtl: false },
    'es' => { name: 'Spanish', native: 'Español', rtl: false },
    'fr' => { name: 'French', native: 'Français', rtl: false },
    'de' => { name: 'German', native: 'Deutsch', rtl: false },
    'it' => { name: 'Italian', native: 'Italiano', rtl: false },
    'pt' => { name: 'Portuguese', native: 'Português', rtl: false },
    'ru' => { name: 'Russian', native: 'Русский', rtl: false },
    'zh' => { name: 'Chinese', native: '中文', rtl: false },
    'ja' => { name: 'Japanese', native: '日本語', rtl: false },
    'ko' => { name: 'Korean', native: '한국어', rtl: false },
    'ar' => { name: 'Arabic', native: 'العربية', rtl: true },
    'he' => { name: 'Hebrew', native: 'עברית', rtl: true },
    'hi' => { name: 'Hindi', native: 'हिन्दी', rtl: false },
    'bn' => { name: 'Bengali', native: 'বাংলা', rtl: false },
    'pa' => { name: 'Punjabi', native: 'ਪੰਜਾਬੀ', rtl: false },
    'te' => { name: 'Telugu', native: 'తెలుగు', rtl: false },
    'mr' => { name: 'Marathi', native: 'मराठी', rtl: false },
    'ta' => { name: 'Tamil', native: 'தமிழ்', rtl: false },
    'ur' => { name: 'Urdu', native: 'اردو', rtl: true },
    'tr' => { name: 'Turkish', native: 'Türkçe', rtl: false },
    'vi' => { name: 'Vietnamese', native: 'Tiếng Việt', rtl: false },
    'th' => { name: 'Thai', native: 'ไทย', rtl: false },
    'nl' => { name: 'Dutch', native: 'Nederlands', rtl: false },
    'pl' => { name: 'Polish', native: 'Polski', rtl: false },
    'sv' => { name: 'Swedish', native: 'Svenska', rtl: false },
    'no' => { name: 'Norwegian', native: 'Norsk', rtl: false },
    'da' => { name: 'Danish', native: 'Dansk', rtl: false },
    'fi' => { name: 'Finnish', native: 'Suomi', rtl: false },
    'cs' => { name: 'Czech', native: 'Čeština', rtl: false },
    'hu' => { name: 'Hungarian', native: 'Magyar', rtl: false },
    'ro' => { name: 'Romanian', native: 'Română', rtl: false },
    'uk' => { name: 'Ukrainian', native: 'Українська', rtl: false },
    'el' => { name: 'Greek', native: 'Ελληνικά', rtl: false },
    'id' => { name: 'Indonesian', native: 'Bahasa Indonesia', rtl: false },
    'ms' => { name: 'Malay', native: 'Bahasa Melayu', rtl: false },
    'fa' => { name: 'Persian', native: 'فارسی', rtl: true },
    'sw' => { name: 'Swahili', native: 'Kiswahili', rtl: false },
    'af' => { name: 'Afrikaans', native: 'Afrikaans', rtl: false },
    'sq' => { name: 'Albanian', native: 'Shqip', rtl: false },
    'am' => { name: 'Amharic', native: 'አማርኛ', rtl: false },
    'hy' => { name: 'Armenian', native: 'Հայերեն', rtl: false },
    'az' => { name: 'Azerbaijani', native: 'Azərbaycan', rtl: false },
    'eu' => { name: 'Basque', native: 'Euskara', rtl: false },
    'be' => { name: 'Belarusian', native: 'Беларуская', rtl: false },
    'bs' => { name: 'Bosnian', native: 'Bosanski', rtl: false },
    'bg' => { name: 'Bulgarian', native: 'Български', rtl: false },
    'ca' => { name: 'Catalan', native: 'Català', rtl: false },
    'hr' => { name: 'Croatian', native: 'Hrvatski', rtl: false },
    'et' => { name: 'Estonian', native: 'Eesti', rtl: false },
    'tl' => { name: 'Filipino', native: 'Filipino', rtl: false },
    'ka' => { name: 'Georgian', native: 'ქართული', rtl: false }
  }.freeze

  def self.get_supported_languages
    cache_key = "#{CACHE_KEY_PREFIX}:supported_languages"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          SUPPORTED_LANGUAGES
        end
      end
    end
  end

  def self.detect_language_from_browser(accept_language_header)
    cache_key = "#{CACHE_KEY_PREFIX}:detect_browser:#{accept_language_header}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          return 'en' unless accept_language_header

          # Parse Accept-Language header
          languages = accept_language_header.split(',').map do |lang|
            parts = lang.split(';')
            code = parts[0].strip.split('-').first
            quality = parts[1] ? parts[1].split('=')[1].to_f : 1.0
            [code, quality]
          end.sort_by { |_, q| -q }

          # Find first supported language
          languages.each do |code, _|
            return code if SUPPORTED_LANGUAGES.key?(code)
          end

          'en' # Default to English
        end
      end
    end
  end

  def self.create_or_update_preference(user, primary_language, secondary_language = nil, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create_update:#{user.id}:#{primary_language}:#{secondary_language}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          preference = LanguagePreference.find_or_initialize_by(user: user)

          if preference.update(
            primary_language: primary_language,
            secondary_language: secondary_language,
            **attributes
          )
            EventPublisher.publish('language_preference.updated', {
              preference_id: preference.id,
              user_id: user.id,
              primary_language: primary_language,
              secondary_language: secondary_language,
              updated_at: preference.updated_at
            })

            clear_user_cache(user.id)
            preference
          else
            false
          end
        end
      end
    end
  end

  def self.get_user_preference(user_id)
    cache_key = "#{CACHE_KEY_PREFIX}:user_preference:#{user_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          LanguagePreference.find_by(user_id: user_id)
        end
      end
    end
  end

  def self.get_fallback_languages(preference)
    cache_key = "#{CACHE_KEY_PREFIX}:fallback:#{preference.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          [preference.primary_language, preference.secondary_language, 'en'].compact.uniq
        end
      end
    end
  end

  def self.get_language_info(language_code)
    cache_key = "#{CACHE_KEY_PREFIX}:language_info:#{language_code}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          SUPPORTED_LANGUAGES[language_code] || SUPPORTED_LANGUAGES['en']
        end
      end
    end
  end

  def self.get_translation_coverage(preference)
    cache_key = "#{CACHE_KEY_PREFIX}:translation_coverage:#{preference.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          # This would integrate with translation service
          # For now, return mock data
          coverage = {
            preference.primary_language => 100,
            preference.secondary_language => 95,
            'en' => 100
          }.compact

          EventPublisher.publish('language_preference.translation_coverage_calculated', {
            preference_id: preference.id,
            user_id: preference.user_id,
            primary_language: preference.primary_language,
            secondary_language: preference.secondary_language,
            coverage: coverage,
            calculated_at: Time.current
          })

          coverage
        end
      end
    end
  end

  def self.get_regional_settings(preference)
    cache_key = "#{CACHE_KEY_PREFIX}:regional_settings:#{preference.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          settings = LocalizationService.get_regional_settings(preference)

          EventPublisher.publish('language_preference.regional_settings_generated', {
            preference_id: preference.id,
            user_id: preference.user_id,
            primary_language: preference.primary_language,
            settings: settings,
            generated_at: Time.current
          })

          settings
        end
      end
    end
  end

  def self.get_language_stats
    cache_key = "#{CACHE_KEY_PREFIX}:language_stats"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          preferences = LanguagePreference.all

          stats = {
            total_users: preferences.count,
            language_distribution: preferences.group(:primary_language).count,
            rtl_languages_count: preferences.count { |p| SUPPORTED_LANGUAGES[p.primary_language][:rtl] },
            top_languages: preferences.group(:primary_language).count.sort_by { |_, count| -count }.first(10).to_h,
            users_with_secondary: preferences.where.not(secondary_language: nil).count,
            default_language_users: preferences.where(primary_language: 'en').count
          }

          EventPublisher.publish('language_preference.stats_generated', {
            total_users: stats[:total_users],
            top_languages_count: stats[:top_languages].count,
            rtl_languages_percentage: (stats[:rtl_languages_count].to_f / stats[:total_users]) * 100,
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  def self.migrate_user_preferences(old_preferences_data)
    cache_key = "#{CACHE_KEY_PREFIX}:migrate:#{old_preferences_data.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('language_preference_management') do
        with_retry do
          migrated_count = 0
          errors = []

          old_preferences_data.each do |user_id, language_data|
            begin
              user = User.find(user_id)
              create_or_update_preference(user, language_data['primary'], language_data['secondary'])
              migrated_count += 1
            rescue => e
              errors << "Failed to migrate user #{user_id}: #{e.message}"
            end
          end

          EventPublisher.publish('language_preference.migration_completed', {
            migrated_count: migrated_count,
            errors_count: errors.count,
            migration_date: Time.current
          })

          { migrated_count: migrated_count, errors: errors }
        end
      end
    end
  end

  private

  def self.clear_user_cache(user_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:user_preference:#{user_id}",
      "#{CACHE_KEY_PREFIX}:fallback:#{user_id}",
      "#{CACHE_KEY_PREFIX}:regional_settings:#{user_id}",
      "#{CACHE_KEY_PREFIX}:translation_coverage:#{user_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end