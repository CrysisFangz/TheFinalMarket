# frozen_string_literal: true

module Translation
  module Events
    class TranslationVerified
      attr_reader :aggregate_id, :source_language, :target_language, :source_key, :quality_score,
                  :verified_by, :verified_at, :timestamp, :correlation_id

      def initialize(aggregate_id:, source_language:, target_language:, source_key:, quality_score:,
                     verified_by:, verified_at:)
        @aggregate_id = aggregate_id
        @source_language = source_language
        @target_language = target_language
        @source_key = source_key
        @quality_score = quality_score
        @verified_by = verified_by
        @verified_at = verified_at
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
          quality_score: quality_score,
          verified_by: verified_by,
          verified_at: verified_at,
          timestamp: timestamp,
          correlation_id: correlation_id
        }
      end
    end
  end
end