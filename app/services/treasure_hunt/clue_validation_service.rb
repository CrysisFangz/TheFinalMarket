module TreasureHunt
  class ClueValidationService
    include ServiceResultHelper

    def initialize(clue, answer)
      @clue = clue
      @answer = answer
    end

    def call
      return failure('Answer cannot be blank') if @answer.blank?

      cache_key = "clue_validation_#{@clue.id}_#{@answer.hash}"

      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        result = validate_answer
        log_validation(result)
        result
      end
    rescue StandardError => e
      Rails.logger.error("Clue validation error: #{e.message}")
      failure('Validation failed due to an error')
    end

    private

    def validate_answer
      case @clue.clue_type.to_sym
      when :product_based
        @answer.to_i == @clue.product_id
      when :category_based
        @answer.to_i == @clue.category_id
      when :riddle, :location_based
        normalize_answer(@answer) == normalize_answer(@clue.correct_answer)
      when :qr_code
        @answer == @clue.qr_code_value
      else
        false
      end
    end

    def normalize_answer(text)
      text.to_s.downcase.strip.gsub(/[^a-z0-9]/, '')
    end

    def log_validation(result)
      Rails.logger.info("Clue validation: clue_id=#{@clue.id}, correct=#{result}")
    end
  end
end