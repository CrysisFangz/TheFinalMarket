class TranslationCache < ApplicationRecord
  validates :source_language, presence: true
  validates :target_language, presence: true
  validates :source_key, presence: true
  validates :source_text, presence: true
  validates :translated_text, presence: true

  # Initialize domain services
  def self.translation_service
    @translation_service ||= Translation::Services::TranslationService.new(
      Translation::Repositories::ActiveRecordTranslationRepository.new,
      ::MessageTranslationService.new
    )
  end

  def self.statistics_service
    @statistics_service ||= Translation::Services::TranslationStatisticsService.new(
      Translation::Repositories::ActiveRecordTranslationRepository.new
    )
  end

  def self.verification_service
    @verification_service ||= Translation::Services::TranslationVerificationService.new(
      Translation::Repositories::ActiveRecordTranslationRepository.new
    )
  end

  # Get or create translation
  def self.get_translation(source_lang, target_lang, key, source_text)
    source_lang_vo = Translation::ValueObjects::Language.new(source_lang)
    target_lang_vo = Translation::ValueObjects::Language.new(target_lang)
    key_vo = Translation::ValueObjects::TranslationKey.new(key)
    text_vo = Translation::ValueObjects::TranslationText.new(source_text)

    result = translation_service.get_translation(source_lang_vo, target_lang_vo, key_vo, text_vo)
    result.value! if result.success?
  end

  # Translate text using service
  def self.translate_text(text, from_lang, to_lang)
    text_vo = Translation::ValueObjects::TranslationText.new(text)
    from_lang_vo = Translation::ValueObjects::Language.new(from_lang)
    to_lang_vo = Translation::ValueObjects::Language.new(to_lang)

    result = translation_service.translate_text(text_vo, from_lang_vo, to_lang_vo)
    result.value! if result.success?
  end

  # Verify translation quality
  def verify!(verified_by: nil)
    result = verification_service.verify_translation(id, verified_by: verified_by)
    if result.success?
      update!(
        verified: true,
        quality_score: 100
      )
    end
    result.success?
  end

  # Get translation statistics
  def self.statistics
    statistics_service.statistics
  end

  # Get missing translations
  def self.missing_translations(source_lang, target_lang)
    source_lang_vo = Translation::ValueObjects::Language.new(source_lang)
    target_lang_vo = Translation::ValueObjects::Language.new(target_lang)

    statistics_service.missing_translations(source_lang_vo, target_lang_vo).map(&:to_s)
  end

  # Bulk translate
  def self.bulk_translate(translations_hash, from_lang, to_lang)
    from_lang_vo = Translation::ValueObjects::Language.new(from_lang)
    to_lang_vo = Translation::ValueObjects::Language.new(to_lang)

    result = translation_service.bulk_translate(translations_hash, from_lang_vo, to_lang_vo)
    result.value! if result.success?
  end

  # Get translation coverage
  def self.coverage(source_lang, target_lang)
    source_lang_vo = Translation::ValueObjects::Language.new(source_lang)
    target_lang_vo = Translation::ValueObjects::Language.new(target_lang)

    statistics_service.coverage(source_lang_vo, target_lang_vo)
  end
end

