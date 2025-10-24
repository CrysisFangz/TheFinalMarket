module Domain
  module SocialCompetitions
    module Events
      class ParticipantRegisteredEvent
        attr_reader :aggregate_id, :user_id, :team_id, :timestamp, :correlation_id

        def initialize(aggregate_id, user_id, team_id = nil)
          @aggregate_id = aggregate_id
          @user_id = user_id
          @team_id = team_id
          @timestamp = Time.current
          @correlation_id = SecureRandom.uuid
        end

        def to_h
          {
            event_type: self.class.name,
            aggregate_id: aggregate_id,
            user_id: user_id,
            team_id: team_id,
            timestamp: timestamp,
            correlation_id: correlation_id
          }
        end
      end
    end
  end
end