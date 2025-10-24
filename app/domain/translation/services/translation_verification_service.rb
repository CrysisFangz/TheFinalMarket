# frozen_string_literal: true

module Translation
  module Services
    # Domain service for translation verification
    class TranslationVerificationService
      # @param repository [Repositories::TranslationRepository] repository instance
      def initialize(repository)
        @repository = repository
      end

      # Verifies a translation
      # @param translation_id [String] translation ID
      # @param verified_by [String, nil] who verified it
      # @return [Dry::Monads::Result] Success with verified translation or Failure with error
      def verify_translation(translation_id, verified_by: nil)
        translation = @repository.find_by_id(translation_id)
        return Failure("Translation not found: #{translation_id}") unless translation

        verified_translation = translation.verify!(verified_by: verified_by)
        saved_translation = @repository.save(verified_translation)

        # Publish event
        publish_verification_event(saved_translation, verified_by)

        Success(saved_translation)
      end

      # Verifies multiple translations
      # @param translation_ids [Array<String>] array of translation IDs
      # @param verified_by [String, nil] who verified them
      # @return [Dry::Monads::Result] Success with verified translations or Failure with error
      def verify_translations(translation_ids, verified_by: nil)
        results = []
        errors = []

        translation_ids.each do |id|
          result = verify_translation(id, verified_by: verified_by)
          if result.success?
            results << result.value!
          else
            errors << result.failure
          end
        end

        if errors.any?
          Failure(errors.join(', '))
        else
          Success(results)
        end
      end

      private

      # Publishes verification event
      # @param translation [Entities::TranslationCache] the verified translation
      # @param verified_by [String, nil] who verified it
      def publish_verification_event(translation, verified_by)
        event = Events::TranslationVerified.new(
          aggregate_id: translation.id,
          source_language: translation.source_language.to_s,
          target_language: translation.target_language.to_s,
          source_key: translation.source_key.to_s,
          quality_score: translation.quality_score.to_i,
          verified_by: verified_by,
          verified_at: Time.current
        )

        # Assuming an event publisher exists
        EventPublisher.publish(event)
      end
    end
  end
end