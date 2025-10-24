# frozen_string_literal: true

require 'securerandom'

module Translation
  module Entities
    # Domain entity representing a TranslationCache entry
    class TranslationCache
      # @param source_language [ValueObjects::Language] source language
      # @param target_language [ValueObjects::Language] target language
      # @param source_key [ValueObjects::TranslationKey] source key
      # @param source_text [ValueObjects::TranslationText] source text
      # @param translated_text [ValueObjects::TranslationText] translated text
      # @param translation_service [String] service used for translation
      # @param quality_score [ValueObjects::QualityScore] quality score
      # @param verified [Boolean] whether verified
      # @param id [String] unique identifier (optional)
      def initialize(source_language:, target_language:, source_key:, source_text:, translated_text:,
                     translation_service: 'auto', quality_score: 80, verified: false, id: nil)
        @id = id || generate_id
        @source_language = source_language
        @target_language = target_language
        @source_key = source_key
        @source_text = source_text
        @translated_text = translated_text
        @translation_service = translation_service
        @quality_score = quality_score
        @verified = verified
        @created_at = Time.current
        @updated_at = Time.current

        validate_invariants
      end

      # @return [String] unique identifier
      attr_reader :id

      # @return [ValueObjects::Language] source language
      attr_reader :source_language

      # @return [ValueObjects::Language] target language
      attr_reader :target_language

      # @return [ValueObjects::TranslationKey] source key
      attr_reader :source_key

      # @return [ValueObjects::TranslationText] source text
      attr_reader :source_text

      # @return [ValueObjects::TranslationText] translated text
      attr_reader :translated_text

      # @return [String] translation service
      attr_reader :translation_service

      # @return [ValueObjects::QualityScore] quality score
      attr_reader :quality_score

      # @return [Boolean] verified status
      attr_reader :verified

      # @return [Time] creation timestamp
      attr_reader :created_at

      # @return [Time] last update timestamp
      attr_reader :updated_at

      # Verifies the translation
      # @param verified_by [String, nil] who verified it
      # @return [TranslationCache] new instance with updated verification
      def verify!(verified_by: nil)
        self.class.new(
          source_language: @source_language,
          target_language: @target_language,
          source_key: @source_key,
          source_text: @source_text,
          translated_text: @translated_text,
          translation_service: @translation_service,
          quality_score: ValueObjects::QualityScore.new(100),
          verified: true,
          id: @id
        )
      end

      # @param other [TranslationCache] entity to compare
      # @return [Boolean] true if entities are equal
      def ==(other)
        return false unless other.is_a?(TranslationCache)
        @id == other.id
      end

      # @return [Integer] hash code
      def hash
        @id.hash
      end

      # @return [Hash] entity data for serialization
      def to_h
        {
          id: @id,
          source_language: @source_language.to_s,
          target_language: @target_language.to_s,
          source_key: @source_key.to_s,
          source_text: @source_text.to_s,
          translated_text: @translated_text.to_s,
          translation_service: @translation_service,
          quality_score: @quality_score.to_i,
          verified: @verified,
          created_at: @created_at,
          updated_at: @updated_at
        }
      end

      private

      # Generates a unique identifier
      # @return [String] unique identifier
      def generate_id
        SecureRandom.uuid
      end

      # Validates business invariants
      # @raise [ArgumentError] if invariants are violated
      def validate_invariants
        unless @source_language == @target_language || @source_language != @target_language
          raise ArgumentError, 'Source and target languages must be different'
        end

        if @source_text.to_s.empty?
          raise ArgumentError, 'Source text cannot be empty'
        end

        if @translated_text.to_s.empty?
          raise ArgumentError, 'Translated text cannot be empty'
        end
      end
    end
  end
end