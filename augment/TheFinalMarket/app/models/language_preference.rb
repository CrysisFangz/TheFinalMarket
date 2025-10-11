class LanguagePreference < ApplicationRecord
  belongs_to :user
  
  validates :user, presence: true
  validates :primary_language, presence: true
  
  # Supported languages (50+ languages)
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
  
  # Get language info
  def language_info
    SUPPORTED_LANGUAGES[primary_language] || SUPPORTED_LANGUAGES['en']
  end
  
  # Check if RTL language
  def rtl?
    language_info[:rtl]
  end
  
  # Get language name
  def language_name
    language_info[:name]
  end
  
  # Get native language name
  def native_language_name
    language_info[:native]
  end
  
  # Get locale
  def locale
    primary_language
  end
  
  # Get fallback languages
  def fallback_languages
    [primary_language, secondary_language, 'en'].compact.uniq
  end
  
  # Auto-detect language from browser
  def self.detect_from_browser(accept_language_header)
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
  
  # Get translation coverage
  def translation_coverage
    # This would integrate with translation service
    # For now, return mock data
    {
      primary_language => 100,
      secondary_language => 95,
      'en' => 100
    }.compact
  end
  
  # Get regional settings
  def regional_settings
    {
      language: primary_language,
      currency: currency_preference,
      date_format: date_format_preference,
      time_format: time_format_preference,
      number_format: number_format_preference,
      rtl: rtl?
    }
  end
  
  private
  
  def currency_preference
    # Map language to common currency
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
    
    currency_map[primary_language] || 'USD'
  end
  
  def date_format_preference
    # US format for English, ISO for most others
    primary_language == 'en' ? 'MM/DD/YYYY' : 'DD/MM/YYYY'
  end
  
  def time_format_preference
    # 12-hour for English, 24-hour for most others
    primary_language == 'en' ? '12h' : '24h'
  end
  
  def number_format_preference
    {
      decimal_separator: primary_language == 'en' ? '.' : ',',
      thousands_separator: primary_language == 'en' ? ',' : '.'
    }
  end
end

