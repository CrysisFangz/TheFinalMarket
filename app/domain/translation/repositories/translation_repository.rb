# frozen_string_literal: true

module Translation
  module Repositories
    # Abstract repository interface for TranslationCache domain entities
    class TranslationRepository
      # Finds a translation by source language, target language, and key
      # @param source_language [ValueObjects::Language] source language
      # @param target_language [ValueObjects::Language] target language
      # @param source_key [ValueObjects::TranslationKey] source key
      # @return [Entities::TranslationCache, nil] the translation or nil if not found
      def find_by_languages_and_key(source_language, target_language, source_key)
        raise NotImplementedError, 'Subclasses must implement #find_by_languages_and_key'
      end

      # Saves a translation to the repository
      # @param translation [Entities::TranslationCache] the translation to save
      # @return [Entities::TranslationCache] the saved translation
      def save(translation)
        raise NotImplementedError, 'Subclasses must implement #save'
      end

      # Finds all translations for a source language
      # @param source_language [ValueObjects::Language] source language
      # @return [Array<Entities::TranslationCache>] array of translations
      def find_by_source_language(source_language)
        raise NotImplementedError, 'Subclasses must implement #find_by_source_language'
      end

      # Finds all translations for a target language
      # @param target_language [ValueObjects::Language] target language
      # @return [Array<Entities::TranslationCache>] array of translations
      def find_by_target_language(target_language)
        raise NotImplementedError, 'Subclasses must implement #find_by_target_language'
      end

      # Finds verified translations
      # @return [Array<Entities::TranslationCache>] array of verified translations
      def find_verified
        raise NotImplementedError, 'Subclasses must implement #find_verified'
      end

      # Counts total number of translations
      # @return [Integer] total count
      def count
        raise NotImplementedError, 'Subclasses must implement #count'
      end

      # Counts translations by source language
      # @param source_language [ValueObjects::Language] source language
      # @return [Integer] count
      def count_by_source_language(source_language)
        raise NotImplementedError, 'Subclasses must implement #count_by_source_language'
      end

      # Counts translations by target language
      # @param target_language [ValueObjects::Language] target language
      # @return [Integer] count
      def count_by_target_language(target_language)
        raise NotImplementedError, 'Subclasses must implement #count_by_target_language'
      end

      # Averages quality score
      # @return [Float] average quality score
      def average_quality_score
        raise NotImplementedError, 'Subclasses must implement #average_quality_score'
      end

      # Finds distinct target languages
      # @return [Array<ValueObjects::Language>] array of unique target languages
      def distinct_target_languages
        raise NotImplementedError, 'Subclasses must implement #distinct_target_languages'
      end

      # Finds distinct source keys for a source language
      # @param source_language [ValueObjects::Language] source language
      # @return [Array<ValueObjects::TranslationKey>] array of unique source keys
      def distinct_source_keys(source_language)
        raise NotImplementedError, 'Subclasses must implement #distinct_source_keys'
      end

      # Finds a translation by ID
      # @param id [String] translation ID
      # @return [Entities::TranslationCache, nil] the translation or nil if not found
      def find_by_id(id)
        raise NotImplementedError, 'Subclasses must implement #find_by_id'
      end

      # Checks if repository is empty
      # @return [Boolean] true if repository contains no translations
      def empty?
        count.zero?
      end
    end
  end
end