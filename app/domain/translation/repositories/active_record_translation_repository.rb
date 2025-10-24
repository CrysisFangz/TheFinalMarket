# frozen_string_literal: true

module Translation
  module Repositories
    # ActiveRecord implementation of TranslationRepository
    class ActiveRecordTranslationRepository < TranslationRepository
      # @param model_class [Class] the ActiveRecord model class (default: ::TranslationCache)
      def initialize(model_class = ::TranslationCache)
        @model_class = model_class
      end

      # Finds a translation by ID
      # @param id [String] translation ID
      # @return [Entities::TranslationCache, nil] the translation or nil if not found
      def find_by_id(id)
        record = @model_class.find_by(id: id)
        return nil unless record

        build_entity_from_record(record)
      end

      # Finds a translation by source language, target language, and key
      # @param source_language [ValueObjects::Language] source language
      # @param target_language [ValueObjects::Language] target language
      # @param source_key [ValueObjects::TranslationKey] source key
      # @return [Entities::TranslationCache, nil] the translation or nil if not found
      def find_by_languages_and_key(source_language, target_language, source_key)
        record = @model_class.find_by(
          source_language: source_language.to_s,
          target_language: target_language.to_s,
          source_key: source_key.to_s
        )
        return nil unless record

        build_entity_from_record(record)
      end

      # Saves a translation to the repository
      # @param translation [Entities::TranslationCache] the translation to save
      # @return [Entities::TranslationCache] the saved translation
      def save(translation)
        record = if translation.id
                   @model_class.find_or_initialize_by(id: translation.id)
                 else
                   @model_class.new
                 end

        # Map entity attributes to record
        record.source_language = translation.source_language.to_s
        record.target_language = translation.target_language.to_s
        record.source_key = translation.source_key.to_s
        record.source_text = translation.source_text.to_s
        record.translated_text = translation.translated_text.to_s
        record.translation_service = translation.translation_service
        record.quality_score = translation.quality_score.to_i
        record.verified = translation.verified

        if record.save
          build_entity_from_record(record)
        else
          raise ValidationError, record.errors.full_messages.join(', ')
        end
      end

      # Finds all translations for a source language
      # @param source_language [ValueObjects::Language] source language
      # @return [Array<Entities::TranslationCache>] array of translations
      def find_by_source_language(source_language)
        records = @model_class.where(source_language: source_language.to_s)
        records.map { |record| build_entity_from_record(record) }
      end

      # Finds all translations for a target language
      # @param target_language [ValueObjects::Language] target language
      # @return [Array<Entities::TranslationCache>] array of translations
      def find_by_target_language(target_language)
        records = @model_class.where(target_language: target_language.to_s)
        records.map { |record| build_entity_from_record(record) }
      end

      # Finds verified translations
      # @return [Array<Entities::TranslationCache>] array of verified translations
      def find_verified
        records = @model_class.where(verified: true)
        records.map { |record| build_entity_from_record(record) }
      end

      # Counts total number of translations
      # @return [Integer] total count
      def count
        @model_class.count
      end

      # Counts translations by source language
      # @param source_language [ValueObjects::Language] source language
      # @return [Integer] count
      def count_by_source_language(source_language)
        @model_class.where(source_language: source_language.to_s).count
      end

      # Counts translations by target language
      # @param target_language [ValueObjects::Language] target language
      # @return [Integer] count
      def count_by_target_language(target_language)
        @model_class.where(target_language: target_language.to_s).count
      end

      # Averages quality score
      # @return [Float] average quality score
      def average_quality_score
        @model_class.average(:quality_score).to_f.round(2)
      end

      # Finds distinct target languages
      # @return [Array<ValueObjects::Language>] array of unique target languages
      def distinct_target_languages
        codes = @model_class.distinct.pluck(:target_language)
        codes.map { |code| ValueObjects::Language.new(code) }
      end

      # Finds distinct source keys for a source language
      # @param source_language [ValueObjects::Language] source language
      # @return [Array<ValueObjects::TranslationKey>] array of unique source keys
      def distinct_source_keys(source_language)
        keys = @model_class.where(source_language: source_language.to_s).distinct.pluck(:source_key)
        keys.map { |key| ValueObjects::TranslationKey.new(key) }
      end

      private

      # Builds a domain entity from an ActiveRecord record
      # @param record [TranslationCache] ActiveRecord record
      # @return [Entities::TranslationCache] domain entity
      def build_entity_from_record(record)
        source_lang = ValueObjects::Language.new(record.source_language)
        target_lang = ValueObjects::Language.new(record.target_language)
        source_key = ValueObjects::TranslationKey.new(record.source_key)
        source_text = ValueObjects::TranslationText.new(record.source_text)
        translated_text = ValueObjects::TranslationText.new(record.translated_text)
        quality_score = ValueObjects::QualityScore.new(record.quality_score)

        Entities::TranslationCache.new(
          source_language: source_lang,
          target_language: target_lang,
          source_key: source_key,
          source_text: source_text,
          translated_text: translated_text,
          translation_service: record.translation_service,
          quality_score: quality_score,
          verified: record.verified,
          id: record.id
        )
      end

      # Custom validation error class
      class ValidationError < StandardError; end
    end
  end
end