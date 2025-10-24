module TreasureHunt
  class CompleteService
    def initialize(treasure_hunt)
      @treasure_hunt = treasure_hunt
    end

    def call
      ActiveRecord::Base.transaction do
        @treasure_hunt.update!(status: :completed, completed_at: Time.current)
        # Schedule asynchronous prize awarding
        AwardPrizesJob.perform_later(@treasure_hunt.id)
        true
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to complete treasure hunt: #{e.message}")
      false
    end

    private

    attr_reader :treasure_hunt
  end
end