# frozen_string_literal: true

module Translation
  module Events
    class TranslationCreated
      attr_reader :aggregate_id, :source_language, :target_language, :source_key, :source_text,
                  :translated_text, :translation_service, :quality_score, :timestamp, :correlation_id

      def initialize(aggregate_id:, source_language:, target_language:, source_key:, source_text:,
                     translated_text:, translation_service:, quality_score:)
        @aggregate_id = aggregate_id
        @source_language = source_language
        @target_language = target_language
        @source_key = source_key
        @source_text = source_text
        @translated_text = translated_text
        @translation_service = translation_service
        @quality_score = quality_score
        @timestamp = Time.current
        @correlation_id = SecureRandom.uuid
      end

      def to_h
        {
          event_type: self.class.name,
          aggregate_id: aggregate_id,
          source_language: source_language,
          target_language: target_language,
          source_key: source_key,
          source_text: source_text,
          translated_text: translated_text,
          translation_service: translation_service,
          quality_score: quality_score,
          timestamp: timestamp,
          correlation_id: correlation_id
        }
      end
    end
  end
end