class LocalizationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'localization'
  CACHE_TTL = 25.minutes

  def self.get_regional_settings(preference)
    cache_key = "#{CACHE_KEY_PREFIX}:regional_settings:#{preference.id}:#{preference.primary_language}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          settings = {
            language: preference.primary_language,
            currency: get_currency_preference(preference.primary_language),
            date_format: get_date_format_preference(preference.primary_language),
            time_format: get_time_format_preference(preference.primary_language),
            number_format: get_number_format_preference(preference.primary_language),
            rtl: is_rtl_language?(preference.primary_language),
            timezone: get_timezone_preference(preference.primary_language),
            measurement_system: get_measurement_system(preference.primary_language)
          }

          EventPublisher.publish('localization.regional_settings_generated', {
            preference_id: preference.id,
            user_id: preference.user_id,
            primary_language: preference.primary_language,
            currency: settings[:currency],
            date_format: settings[:date_format],
            rtl: settings[:rtl],
            generated_at: Time.current
          })

          settings
        end
      end
    end
  end

  def self.format_currency(amount, currency_code, locale = 'en')
    cache_key = "#{CACHE_KEY_PREFIX}:format_currency:#{amount}:#{currency_code}:#{locale}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          # This would integrate with money gem or similar
          # For now, use Rails number formatting

          formatted_amount = ActionController::Base.helpers.number_to_currency(
            amount,
            unit: get_currency_symbol(currency_code),
            format: get_currency_format(currency_code)
          )

          EventPublisher.publish('localization.currency_formatted', {
            amount: amount,
            currency_code: currency_code,
            locale: locale,
            formatted_amount: formatted_amount,
            formatted_at: Time.current
          })

          formatted_amount
        end
      end
    end
  end

  def self.format_date(date, format = nil, locale = 'en')
    cache_key = "#{CACHE_KEY_PREFIX}:format_date:#{date.to_i}:#{format}:#{locale}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          # Use Rails I18n for date formatting
          I18n.locale = locale.to_sym

          formatted_date = if format
                            I18n.l(date, format: format)
                          else
                            I18n.l(date)
                          end

          EventPublisher.publish('localization.date_formatted', {
            date: date,
            format: format,
            locale: locale,
            formatted_date: formatted_date,
            formatted_at: Time.current
          })

          formatted_date
        end
      end
    end
  end

  def self.format_number(number, locale = 'en')
    cache_key = "#{CACHE_KEY_PREFIX}:format_number:#{number}:#{locale}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          I18n.locale = locale.to_sym
          formatted_number = ActionController::Base.helpers.number_with_delimiter(number)

          EventPublisher.publish('localization.number_formatted', {
            number: number,
            locale: locale,
            formatted_number: formatted_number,
            formatted_at: Time.current
          })

          formatted_number
        end
      end
    end
  end

  def self.localize_text(key, locale = 'en', interpolations = {})
    cache_key = "#{CACHE_KEY_PREFIX}:localize_text:#{key}:#{locale}:#{interpolations.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          I18n.locale = locale.to_sym
          localized_text = I18n.t(key, **interpolations)

          EventPublisher.publish('localization.text_localized', {
            key: key,
            locale: locale,
            interpolations: interpolations,
            localized_text: localized_text,
            localized_at: Time.current
          })

          localized_text
        end
      end
    end
  end

  def self.get_locale_settings(locale)
    cache_key = "#{CACHE_KEY_PREFIX}:locale_settings:#{locale}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          settings = {
            language_code: locale,
            language_name: get_language_name(locale),
            native_name: get_native_language_name(locale),
            rtl: is_rtl_language?(locale),
            text_direction: is_rtl_language?(locale) ? 'rtl' : 'ltr',
            date_format: get_date_format_preference(locale),
            time_format: get_time_format_preference(locale),
            number_format: get_number_format_preference(locale),
            currency: get_currency_preference(locale),
            timezone: get_timezone_preference(locale),
            measurement_system: get_measurement_system(locale),
            first_day_of_week: get_first_day_of_week(locale)
          }

          EventPublisher.publish('localization.locale_settings_generated', {
            locale: locale,
            rtl: settings[:rtl],
            currency: settings[:currency],
            generated_at: Time.current
          })

          settings
        end
      end
    end
  end

  def self.validate_locale(locale)
    cache_key = "#{CACHE_KEY_PREFIX}:validate_locale:#{locale}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          is_valid = I18n.available_locales.include?(locale.to_sym) ||
                    LanguagePreferenceManagementService::SUPPORTED_LANGUAGES.key?(locale)

          validation = {
            valid: is_valid,
            supported: LanguagePreferenceManagementService::SUPPORTED_LANGUAGES.key?(locale),
            rtl: is_rtl_language?(locale),
            fallback_locale: is_valid ? locale : 'en'
          }

          EventPublisher.publish('localization.locale_validated', {
            locale: locale,
            is_valid: validation[:valid],
            is_supported: validation[:supported],
            validated_at: Time.current
          })

          validation
        end
      end
    end
  end

  def self.get_available_locales
    cache_key = "#{CACHE_KEY_PREFIX}:available_locales"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          locales = I18n.available_locales.map(&:to_s) +
                   LanguagePreferenceManagementService::SUPPORTED_LANGUAGES.keys

          locales.uniq.sort
        end
      end
    end
  end

  def self.get_locale_compatibility_matrix
    cache_key = "#{CACHE_KEY_PREFIX}:compatibility_matrix"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('localization') do
        with_retry do
          locales = get_available_locales
          matrix = {}

          locales.each do |locale|
            matrix[locale] = {
              rtl: is_rtl_language?(locale),
              currency: get_currency_preference(locale),
              date_format: get_date_format_preference(locale),
              time_format: get_time_format_preference(locale),
              compatible_locales: find_compatible_locales(locale)
            }
          end

          EventPublisher.publish('localization.compatibility_matrix_generated', {
            locales_count: locales.count,
            rtl_locales_count: matrix.values.count { |l| l[:rtl] },
            generated_at: Time.current
          })

          matrix
        end
      end
    end
  end

  private

  def self.get_currency_preference(language_code)
    currency_map = {
      'en' => 'USD',
      'es' => 'EUR',
      'fr' => 'EUR',
      'de' => 'EUR',
      'it' => 'EUR',
      'pt' => 'EUR',
      'ru' => 'RUB',
      'zh' => 'CNY',
      'ja' => 'JPY',
      'ko' => 'KRW',
      'ar' => 'SAR',
      'he' => 'ILS',
      'hi' => 'INR'
    }

    currency_map[language_code] || 'USD'
  end

  def self.get_date_format_preference(language_code)
    # US format for English, ISO for most others
    language_code == 'en' ? 'MM/DD/YYYY' : 'DD/MM/YYYY'
  end

  def self.get_time_format_preference(language_code)
    # 12-hour for English, 24-hour for most others
    language_code == 'en' ? '12h' : '24h'
  end

  def self.get_number_format_preference(language_code)
    {
      decimal_separator: language_code == 'en' ? '.' : ',',
      thousands_separator: language_code == 'en' ? ',' : '.'
    }
  end

  def self.get_timezone_preference(language_code)
    timezone_map = {
      'en' => 'America/New_York',
      'es' => 'Europe/Madrid',
      'fr' => 'Europe/Paris',
      'de' => 'Europe/Berlin',
      'it' => 'Europe/Rome',
      'pt' => 'Europe/Lisbon',
      'ru' => 'Europe/Moscow',
      'zh' => 'Asia/Shanghai',
      'ja' => 'Asia/Tokyo',
      'ko' => 'Asia/Seoul',
      'ar' => 'Asia/Riyadh',
      'he' => 'Asia/Jerusalem',
      'hi' => 'Asia/Kolkata'
    }

    timezone_map[language_code] || 'UTC'
  end

  def self.get_measurement_system(language_code)
    # Metric for most countries, Imperial for US and some others
    imperial_countries = ['en', 'hi'] # US English and Hindi (India uses metric)

    imperial_countries.include?(language_code) ? 'imperial' : 'metric'
  end

  def self.get_first_day_of_week(language_code)
    # Monday for most countries, Sunday for US and some others
    sunday_start = ['en', 'ar', 'he', 'fa']

    sunday_start.include?(language_code) ? 'sunday' : 'monday'
  end

  def self.is_rtl_language?(language_code)
    rtl_languages = ['ar', 'he', 'fa', 'ur']
    rtl_languages.include?(language_code)
  end

  def self.get_language_name(language_code)
    LanguagePreferenceManagementService::SUPPORTED_LANGUAGES[language_code]&.[](:name) || 'Unknown'
  end

  def self.get_native_language_name(language_code)
    LanguagePreferenceManagementService::SUPPORTED_LANGUAGES[language_code]&.[](:native) || language_code
  end

  def self.get_currency_symbol(currency_code)
    currency_symbols = {
      'USD' => '$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      'CNY' => '¥',
      'KRW' => '₩',
      'INR' => '₹',
      'RUB' => '₽',
      'SAR' => '﷼',
      'ILS' => '₪'
    }

    currency_symbols[currency_code] || currency_code
  end

  def self.get_currency_format(currency_code)
    case currency_code
    when 'USD', 'EUR', 'GBP'
      '%u%n'
    when 'JPY', 'KRW', 'CNY'
      '%u %n'
    else
      '%u%n'
    end
  end

  def self.find_compatible_locales(locale)
    # Find locales that share similar formatting preferences
    compatible = []

    all_locales = get_available_locales

    target_settings = get_locale_settings(locale)

    all_locales.each do |other_locale|
      next if other_locale == locale

      other_settings = get_locale_settings(other_locale)

      # Check compatibility based on key formatting preferences
      compatibility_score = 0
      compatibility_score += 1 if target_settings[:rtl] == other_settings[:rtl]
      compatibility_score += 1 if target_settings[:date_format] == other_settings[:date_format]
      compatibility_score += 1 if target_settings[:time_format] == other_settings[:time_format]
      compatibility_score += 1 if target_settings[:currency] == other_settings[:currency]

      compatible << other_locale if compatibility_score >= 2
    end

    compatible.first(5) # Return top 5 compatible locales
  end

  def self.clear_localization_cache
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:regional_settings",
      "#{CACHE_KEY_PREFIX}:locale_settings",
      "#{CACHE_KEY_PREFIX}:available_locales",
      "#{CACHE_KEY_PREFIX}:compatibility_matrix"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end