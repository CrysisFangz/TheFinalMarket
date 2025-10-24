module TreasureHunt
  class StartService
    def initialize(treasure_hunt)
      @treasure_hunt = treasure_hunt
    end

    def call
      ActiveRecord::Base.transaction do
        @treasure_hunt.update!(status: :active, started_at: Time.current)
        # Optionally, trigger events or notifications here
        true
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to start treasure hunt: #{e.message}")
      false
    end

    private

    attr_reader :treasure_hunt
  end
end