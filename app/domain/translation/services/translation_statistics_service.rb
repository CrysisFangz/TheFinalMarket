# frozen_string_literal: true

module Translation
  module Services
    # Domain service for translation statistics and analytics
    class TranslationStatisticsService
      # @param repository [Repositories::TranslationRepository] repository instance
      def initialize(repository)
        @repository = repository
      end

      # Gets overall translation statistics
      # @return [Hash] statistics hash
      def statistics
        {
          total_translations: @repository.count,
          verified_translations: @repository.find_verified.count,
          languages: @repository.distinct_target_languages.count,
          average_quality: @repository.average_quality_score
        }
      end

      # Gets missing translations for a language pair
      # @param source_lang [ValueObjects::Language] source language
      # @param target_lang [ValueObjects::Language] target language
      # @return [Array<ValueObjects::TranslationKey>] array of missing keys
      def missing_translations(source_lang, target_lang)
        source_keys = @repository.distinct_source_keys(source_lang)
        target_keys = @repository.find_by_target_language(target_lang)
                                 .select { |t| t.source_language == source_lang }
                                 .map(&:source_key)

        source_keys - target_keys
      end

      # Calculates translation coverage for a language pair
      # @param source_lang [ValueObjects::Language] source language
      # @param target_lang [ValueObjects::Language] target language
      # @return [Float] coverage percentage (0-100)
      def coverage(source_lang, target_lang)
        source_count = @repository.count_by_source_language(source_lang)
        return 100.0 if source_count.zero?

        target_count = @repository.find_by_target_language(target_lang)
                                  .select { |t| t.source_language == source_lang }
                                  .count

        ((target_count.to_f / source_count) * 100).round(2)
      end

      # Gets statistics by source language
      # @return [Hash] hash of language => count
      def statistics_by_source_language
        @repository.distinct_target_languages.each_with_object({}) do |lang, hash|
          hash[lang.to_s] = @repository.count_by_target_language(lang)
        end
      end

      # Gets statistics by target language
      # @return [Hash] hash of language => count
      def statistics_by_target_language
        @repository.distinct_target_languages.each_with_object({}) do |lang, hash|
          hash[lang.to_s] = @repository.count_by_target_language(lang)
        end
      end
    end
  end
end