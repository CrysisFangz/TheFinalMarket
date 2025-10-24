# frozen_string_literal: true

require 'dry/monads'

module Translation
  module Services
    # Domain service for translation operations
    class TranslationService
      include Dry::Monads[:result]

                  # @param repository [Repositories::TranslationRepository] repository instance
      # @param translation_engine [Object] external translation engine (e.g., MessageTranslationService)
      def initialize(repository, translation_engine = nil)
        @repository = repository
        @translation_engine = translation_engine || DefaultTranslationEngine.new
        @circuit_breaker = ::CircuitBreaker.new(failure_threshold: 3, recovery_timeout: 30.seconds)
        @cache = Concurrent::Map.new # In-memory cache for performance
      end</search>
</search_and_replace></search>
</search_and_replace>

            # Gets or creates a translation
      # @param source_lang [ValueObjects::Language] source language
      # @param target_lang [ValueObjects::Language] target language
      # @param key [ValueObjects::TranslationKey] source key
      # @param source_text [ValueObjects::TranslationText] source text
      # @return [Dry::Monads::Result] Success with translated text or Failure with error
      def get_translation(source_lang, target_lang, key, source_text)
        cache_key = "#{source_lang.to_s}:#{target_lang.to_s}:#{key.to_s}"

        # Check cache first
        cached_result = @cache.get(cache_key)
        return Success(cached_result) if cached_result

        # Try to find existing translation
        cached = @repository.find_by_languages_and_key(source_lang, target_lang, key)

        if cached
          @cache.put(cache_key, cached.translated_text.to_s)
          return Success(cached.translated_text.to_s)
        end

        # Create new translation
        result = translate_and_save(source_lang, target_lang, key, source_text)
        if result.success?
          @cache.put(cache_key, result.value!)
        end
        result
      end</search>
</search_and_replace>

      # Translates text using the translation engine
      # @param text [ValueObjects::TranslationText] text to translate
      # @param from_lang [ValueObjects::Language] from language
      # @param to_lang [ValueObjects::Language] to language
      # @return [Dry::Monads::Result] Success with translated text or Failure with error
      def translate_text(text, from_lang, to_lang)
        @translation_engine.translate(text.to_s, from_lang.to_s, to_lang.to_s)
      end

      # Bulk translates multiple texts
      # @param translations_hash [Hash] hash of key => text
      # @param from_lang [ValueObjects::Language] from language
      # @param to_lang [ValueObjects::Language] to language
      # @return [Dry::Monads::Result] Success with results hash or Failure with error
      def bulk_translate(translations_hash, from_lang, to_lang)
        results = {}

        translations_hash.each do |key, text|
          key_vo = ValueObjects::TranslationKey.new(key)
          text_vo = ValueObjects::TranslationText.new(text)

          result = get_translation(from_lang, to_lang, key_vo, text_vo)
          return Failure(result.failure) if result.failure?

          results[key] = result.value!
        end

        Success(results)
      end

      private

            # Translates and saves a new translation
      # @param source_lang [ValueObjects::Language] source language
      # @param target_lang [ValueObjects::Language] target language
      # @param key [ValueObjects::TranslationKey] source key
      # @param source_text [ValueObjects::TranslationText] source text
      # @return [Dry::Monads::Result] Success with translated text or Failure with error
      def translate_and_save(source_lang, target_lang, key, source_text)
        @circuit_breaker.execute do
          translate_result = translate_text(source_text, source_lang, target_lang)
          return translate_result if translate_result.failure?

          translated_text = ValueObjects::TranslationText.new(translate_result.value!)
          quality_score = ValueObjects::QualityScore.new(80) # Default score

          translation = Entities::TranslationCache.new(
            source_language: source_lang,
            target_language: target_lang,
            source_key: key,
            source_text: source_text,
            translated_text: translated_text,
            quality_score: quality_score
          )

          saved_translation = @repository.save(translation)

          # Publish event
          publish_creation_event(saved_translation)

          Success(saved_translation.translated_text.to_s)
        end
      rescue ::CircuitBreaker::Open => e
        Failure("Translation service unavailable: #{e.message}")
      end</search>
</search_and_replace>

            # Default translation engine for fallback
      class DefaultTranslationEngine
        def translate(text, from_lang, to_lang)
          # Try to use MessageTranslationService if available
          if defined?(::MessageTranslationService)
            service = ::MessageTranslationService.new
            result = service.execute_real_time_message_translation(text, from_lang, [to_lang])
            return Success(result.value![:translated_text]) if result.success?
          end

          # Fallback to mock
          Success("[#{to_lang.upcase}] #{text}")
        end
      end

      # Publishes creation event
      # @param translation [Entities::TranslationCache] the created translation
      def publish_creation_event(translation)
        event = Events::TranslationCreated.new(
          aggregate_id: translation.id,
          source_language: translation.source_language.to_s,
          target_language: translation.target_language.to_s,
          source_key: translation.source_key.to_s,
          source_text: translation.source_text.to_s,
          translated_text: translation.translated_text.to_s,
          translation_service: translation.translation_service,
          quality_score: translation.quality_score.to_i
        )

        # Assuming an event publisher exists
        EventPublisher.publish(event)
      end
    end
  end
end</search>
</search_and_replace>