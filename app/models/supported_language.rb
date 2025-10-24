# Supported Language Model
# Manages language support with basic attributes and associations.

class SupportedLanguage < ApplicationRecord
  # Associations
  has_many :user_language_preferences, foreign_key: 'language_code', primary_key: 'code'
  has_many :native_language_preferences, class_name: 'UserLanguagePreference', foreign_key: 'native_language_code', primary_key: 'code'
  has_many :translation_pairs, foreign_key: 'source_language_code', primary_key: 'code'
  has_many :target_translation_pairs, class_name: 'TranslationPair', foreign_key: 'target_language_code', primary_key: 'code'

  has_many :language_proficiency_standards, dependent: :destroy
  has_many :cultural_communication_norms, dependent: :destroy
  has_many :language_specific_features, dependent: :destroy

  # Validations
  validates :code, presence: true, uniqueness: true, length: { is: 2 }, format: { with: /\A[a-z]{2}\z/ }
  validates :name, presence: true, length: { maximum: 100 }
  validates :native_name, presence: true, length: { maximum: 100 }
  validates :english_name, presence: true, length: { maximum: 100 }
  validates :rtl, inclusion: { in: [true, false] }
  validates :active, inclusion: { in: [true, false] }
  validates :translation_quality_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1.0 }

  # Callbacks
  before_save :update_language_metadata

  # Enumerations
  enum status: {
    experimental: 'experimental',
    beta: 'beta',
    stable: 'stable',
    premium: 'premium',
    enterprise: 'enterprise'
  }

  enum script_direction: {
    ltr: 'ltr',
    rtl: 'rtl',
    ttb: 'ttb'
  }

  # Scopes
  scope :active_languages, -> { where(active: true) }
  scope :stable_languages, -> { where(status: :stable) }
  scope :rtl_languages, -> { where(rtl: true) }
  scope :high_quality_languages, -> { where('translation_quality_score > ?', 0.8) }
  scope :by_translation_quality, -> { order(translation_quality_score: :desc) }
  scope :by_usage_frequency, -> { order(usage_frequency: :desc) }

  # Utility methods

  def requires_translation_from?(source_language)
    code != source_language.code
  end

  def supports_rtl_text?
    rtl?
  end

  def has_high_translation_quality?
    translation_quality_score > 0.8
  end

  def is_commonly_used?
    usage_frequency > 1000
  end

  def current_language_metadata
    {
      code: code,
      name: name,
      native_name: native_name,
      english_name: english_name,
      rtl: rtl,
      status: status,
      translation_quality_score: translation_quality_score,
      usage_frequency: usage_frequency,
      last_updated: updated_at
    }
  end

  private

  def update_language_metadata
    begin
      self.metadata_version ||= 0
      self.metadata_version += 1
      self.last_metadata_update ||= Time.current
      self.language_metadata ||= {}
      self.language_metadata[:updated_by] = 'system'
      self.language_metadata[:update_reason] = 'automated_optimization'
    rescue StandardError => e
      Rails.logger.error "Error updating language metadata: #{e.message}"
    end
  end

  # Class methods

  def self.find_by_code(code)
    find_by(code: code)
  end

  def self.active_languages_for_selection
    active_languages.stable_languages.by_usage_frequency.limit(20)
  end

  def self.find_or_initialize_by_code(code, language_data = {})
    find_by_code(code) || new(code: code).tap { |lang| lang.assign_attributes(language_data) }
  end
end



