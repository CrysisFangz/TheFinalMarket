class LanguagePreferencePresenter
  include CircuitBreaker
  include Retryable

  def initialize(preference)
    @preference = preference
  end

  def as_json(options = {})
    cache_key = "language_preference_presenter:#{@preference.id}:#{@preference.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('language_preference_presenter') do
        with_retry do
          {
            id: @preference.id,
            primary_language: @preference.primary_language,
            secondary_language: @preference.secondary_language,
            created_at: @preference.created_at,
            updated_at: @preference.updated_at,
            user: user_data,
            language_info: language_info_data,
            fallback_languages: fallback_languages_data,
            regional_settings: regional_settings_data,
            translation_coverage: translation_coverage_data,
            locale_settings: locale_settings_data,
            compatibility: compatibility_data
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
        can_change: true,
        available_languages: available_languages,
        recommended_languages: recommended_languages,
        current_session_locale: I18n.locale.to_s
      }
    )
  end

  private

  def user_data
    Rails.cache.fetch("preference_user:#{@preference.user_id}", expires_in: 30.minutes) do
      with_circuit_breaker('user_data') do
        with_retry do
          {
            id: @preference.user.id,
            username: @preference.user.username,
            email: @preference.user.email,
            registration_date: @preference.user.created_at,
            total_orders: @preference.user.orders.count,
            preferred_currency: @preference.user.preferred_currency
          }
        end
      end
    end
  end

  def language_info_data
    Rails.cache.fetch("preference_language_info:#{@preference.primary_language}", expires_in: 30.minutes) do
      with_circuit_breaker('language_info_data') do
        with_retry do
          info = LanguagePreferenceManagementService.get_language_info(@preference.primary_language)

          {
            name: info[:name],
            native_name: info[:native],
            rtl: info[:rtl],
            script: determine_script(@preference.primary_language),
            region: determine_region(@preference.primary_language),
            popularity_rank: get_language_popularity_rank(@preference.primary_language)
          }
        end
      end
    end
  end

  def fallback_languages_data
    Rails.cache.fetch("preference_fallback:#{@preference.id}", expires_in: 20.minutes) do
      with_circuit_breaker('fallback_languages_data') do
        with_retry do
          fallbacks = LanguagePreferenceManagementService.get_fallback_languages(@preference)

          fallbacks.map do |lang_code|
            info = LanguagePreferenceManagementService.get_language_info(lang_code)
            {
              code: lang_code,
              name: info[:name],
              native_name: info[:native],
              rtl: info[:rtl],
              priority: fallbacks.index(lang_code) + 1
            }
          end
        end
      end
    end
  end

  def regional_settings_data
    Rails.cache.fetch("preference_regional:#{@preference.id}", expires_in: 15.minutes) do
      with_circuit_breaker('regional_settings_data') do
        with_retry do
          LanguagePreferenceManagementService.get_regional_settings(@preference)
        end
      end
    end
  end

  def translation_coverage_data
    Rails.cache.fetch("preference_translation:#{@preference.id}", expires_in: 15.minutes) do
      with_circuit_breaker('translation_coverage_data') do
        with_retry do
          coverage = LanguagePreferenceManagementService.get_translation_coverage(@preference)

          {
            coverage_percentage: calculate_coverage_percentage(coverage),
            fully_translated: coverage.values.all? { |c| c >= 100 },
            partially_translated: coverage.values.any? { |c| c.between?(50, 99) },
            missing_translations: coverage.select { |_, c| c < 50 },
            last_updated: Time.current
          }
        end
      end
    end
  end

  def locale_settings_data
    Rails.cache.fetch("preference_locale:#{@preference.primary_language}", expires_in: 20.minutes) do
      with_circuit_breaker('locale_settings_data') do
        with_retry do
          LocalizationService.get_locale_settings(@preference.primary_language)
        end
      end
    end
  end

  def compatibility_data
    Rails.cache.fetch("preference_compatibility:#{@preference.primary_language}", expires_in: 25.minutes) do
      with_circuit_breaker('compatibility_data') do
        with_retry do
          matrix = LocalizationService.get_locale_compatibility_matrix
          current_locale_data = matrix[@preference.primary_language]

          {
            compatible_locales: current_locale_data&.[](:compatible_locales) || [],
            rtl_compatibility: find_rtl_compatible_locales(matrix),
            currency_compatibility: find_currency_compatible_locales(matrix, current_locale_data),
            format_compatibility: find_format_compatible_locales(matrix, current_locale_data)
          }
        end
      end
    end
  end

  def available_languages
    Rails.cache.fetch("available_languages", expires_in: 30.minutes) do
      with_circuit_breaker('available_languages') do
        with_retry do
          LanguagePreferenceManagementService.get_supported_languages.map do |code, info|
            {
              code: code,
              name: info[:name],
              native_name: info[:native],
              rtl: info[:rtl],
              popular: is_popular_language?(code)
            }
          end.sort_by { |lang| [lang[:rtl] ? 1 : 0, lang[:popular] ? 0 : 1, lang[:name]] }
        end
      end
    end
  end

  def recommended_languages
    Rails.cache.fetch("recommended_languages:#{@preference.user_id}", expires_in: 20.minutes) do
      with_circuit_breaker('recommended_languages') do
        with_retry do
          # Recommend languages based on user location, browser preferences, etc.
          recommendations = []

          # Add secondary language if set
          if @preference.secondary_language
            info = LanguagePreferenceManagementService.get_language_info(@preference.secondary_language)
            recommendations << {
              code: @preference.secondary_language,
              name: info[:name],
              native_name: info[:native],
              reason: 'Your secondary language preference',
              priority: 1
            }
          end

          # Add popular languages in user's region
          user_region_languages = get_region_languages(@preference.user)
          user_region_languages.each do |code|
            next if code == @preference.primary_language || code == @preference.secondary_language

            info = LanguagePreferenceManagementService.get_language_info(code)
            recommendations << {
              code: code,
              name: info[:name],
              native_name: info[:native],
              reason: 'Popular in your region',
              priority: 2
            }
          end

          # Add compatible languages
          compatibility_data[:compatible_locales].first(3).each do |code|
            next if code == @preference.primary_language || code == @preference.secondary_language

            info = LanguagePreferenceManagementService.get_language_info(code)
            recommendations << {
              code: code,
              name: info[:name],
              native_name: info[:native],
              reason: 'Similar formatting preferences',
              priority: 3
            }
          end

          recommendations.first(5)
        end
      end
    end
  end

  def determine_script(language_code)
    script_map = {
      'zh' => 'Simplified Chinese',
      'ja' => 'Han',
      'ko' => 'Hangul',
      'ar' => 'Arabic',
      'he' => 'Hebrew',
      'hi' => 'Devanagari',
      'ru' => 'Cyrillic',
      'el' => 'Greek',
      'th' => 'Thai',
      'vi' => 'Latin'
    }

    script_map[language_code] || 'Latin'
  end

  def determine_region(language_code)
    region_map = {
      'en' => 'North America',
      'es' => 'Spain/Latin America',
      'fr' => 'France/Canada',
      'de' => 'Germany/Austria',
      'it' => 'Italy',
      'pt' => 'Portugal/Brazil',
      'ru' => 'Russia',
      'zh' => 'China',
      'ja' => 'Japan',
      'ko' => 'South Korea',
      'ar' => 'Middle East',
      'he' => 'Israel',
      'hi' => 'India'
    }

    region_map[language_code] || 'Global'
  end

  def get_language_popularity_rank(language_code)
    popularity_ranks = {
      'en' => 1,
      'zh' => 2,
      'hi' => 3,
      'es' => 4,
      'fr' => 5,
      'ar' => 6,
      'ru' => 7,
      'pt' => 8,
      'ja' => 9,
      'de' => 10
    }

    popularity_ranks[language_code] || 999
  end

  def calculate_coverage_percentage(coverage)
    return 0 if coverage.empty?

    total_coverage = coverage.values.sum
    (total_coverage.to_f / coverage.values.count)
  end

  def find_rtl_compatible_locales(matrix)
    matrix.select { |_, data| data[:rtl] }.keys
  end

  def find_currency_compatible_locales(matrix, current_data)
    return [] unless current_data

    matrix.select { |_, data| data[:currency] == current_data[:currency] }.keys
  end

  def find_format_compatible_locales(matrix, current_data)
    return [] unless current_data

    matrix.select do |_, data|
      data[:date_format] == current_data[:date_format] &&
      data[:time_format] == current_data[:time_format]
    end.keys
  end

  def is_popular_language?(language_code)
    popular_languages = ['en', 'es', 'fr', 'de', 'zh', 'ja', 'hi', 'ar', 'pt', 'ru']
    popular_languages.include?(language_code)
  end

  def get_region_languages(user)
    # This would use geolocation or user profile data
    # For now, return common languages
    ['en', 'es', 'fr', 'de', 'it', 'pt']
  end
end