module TreasureHunt
  class JoinService
    def initialize(treasure_hunt, user)
      @treasure_hunt = treasure_hunt
      @user = user
    end

    def call
      return false unless can_participate?

      ActiveRecord::Base.transaction do
        participation = @treasure_hunt.treasure_hunt_participations.create!(
          user: @user,
          started_at: Time.current,
          clues_found: 0,
          current_clue_index: 0
        )
        participation
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to join treasure hunt: #{e.message}")
      false
    end

    def can_participate?
      @treasure_hunt.active? &&
      @treasure_hunt.starts_at <= Time.current &&
      @treasure_hunt.ends_at >= Time.current &&
      !@treasure_hunt.participants.include?(@user) &&
      (@treasure_hunt.max_participants.nil? || @treasure_hunt.participants.count < @treasure_hunt.max_participants)
    end

    attr_reader :treasure_hunt, :user
  end
end