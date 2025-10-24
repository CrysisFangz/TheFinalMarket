module TreasureHunt
  class HintService
    include ServiceResultHelper

    def initialize(clue, hint_level = 1)
      @clue = clue
      @hint_level = hint_level
    end

    def call
      cache_key = "clue_hint_#{@clue.id}_level_#{@hint_level}"

      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        retrieve_hint
      end
    rescue StandardError => e
      Rails.logger.error("Hint retrieval error: #{e.message}")
      failure('Failed to retrieve hint')
    end

    private

    def retrieve_hint
      hints = @clue.hint_text&.split('||') || []
      hint = hints[@hint_level - 1]

      if hint.present?
        success(hint)
      else
        failure('No hint available at this level')
      end
    end
  end
end