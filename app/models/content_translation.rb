class ContentTranslation < ApplicationRecord
  belongs_to :translatable, polymorphic: true
  
  validates :locale, presence: true
  validates :attribute, presence: true
  validates :translatable_id, uniqueness: { scope: [:translatable_type, :locale, :attribute] }
  
  scope :for_locale, ->(locale) { where(locale: locale) }
  scope :for_attribute, ->(attribute) { where(attribute: attribute) }
  scope :verified, -> { where(verified: true) }
  
  # Translators
  enum translator: {
    manual: 0,
    google: 1,
    deepl: 2,
    microsoft: 3,
    amazon: 4
  }
  
  # Auto-translate using service
  def self.auto_translate(model, attribute, from_locale, to_locale)
    original_value = model.send(attribute)
    return nil unless original_value
    
    translated_value = TranslationService.translate(original_value, from_locale, to_locale)
    
    create!(
      translatable: model,
      locale: to_locale,
      attribute: attribute,
      value: translated_value,
      translator: detect_translator,
      verified: false
    )
  end
  
  private
  
  def self.detect_translator
    if ENV['GOOGLE_TRANSLATE_API_KEY']
      :google
    elsif ENV['DEEPL_API_KEY']
      :deepl
    else
      :manual
    end
  end
end

