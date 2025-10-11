class TranslationCache < ApplicationRecord
  validates :source_language, presence: true
  validates :target_language, presence: true
  validates :source_key, presence: true
  validates :source_text, presence: true
  validates :translated_text, presence: true
  
  # Get or create translation
  def self.get_translation(source_lang, target_lang, key, source_text)
    # Try to find existing translation
    cached = find_by(
      source_language: source_lang,
      target_language: target_lang,
      source_key: key
    )
    
    return cached.translated_text if cached
    
    # Create new translation
    translated = translate_text(source_text, source_lang, target_lang)
    
    create!(
      source_language: source_lang,
      target_language: target_lang,
      source_key: key,
      source_text: source_text,
      translated_text: translated,
      translation_service: 'auto',
      quality_score: 80
    )
    
    translated
  end
  
  # Translate text using service
  def self.translate_text(text, from_lang, to_lang)
    # This would integrate with Google Translate, DeepL, etc.
    # For now, return mock translation
    "[#{to_lang.upcase}] #{text}"
  end
  
  # Verify translation quality
  def verify!(verified_by: nil)
    update!(
      verified: true,
      quality_score: 100
    )
  end
  
  # Get translation statistics
  def self.statistics
    {
      total_translations: count,
      verified_translations: where(verified: true).count,
      languages: distinct.pluck(:target_language).count,
      average_quality: average(:quality_score).to_f.round(2)
    }
  end
  
  # Get missing translations
  def self.missing_translations(source_lang, target_lang)
    # Find keys that exist in source but not in target
    source_keys = where(source_language: source_lang).pluck(:source_key)
    target_keys = where(
      source_language: source_lang,
      target_language: target_lang
    ).pluck(:source_key)
    
    source_keys - target_keys
  end
  
  # Bulk translate
  def self.bulk_translate(translations_hash, from_lang, to_lang)
    results = {}
    
    translations_hash.each do |key, text|
      results[key] = get_translation(from_lang, to_lang, key, text)
    end
    
    results
  end
  
  # Get translation coverage
  def self.coverage(source_lang, target_lang)
    source_count = where(source_language: source_lang).count
    return 100 if source_count.zero?
    
    target_count = where(
      source_language: source_lang,
      target_language: target_lang
    ).count
    
    ((target_count.to_f / source_count) * 100).round(2)
  end
end

