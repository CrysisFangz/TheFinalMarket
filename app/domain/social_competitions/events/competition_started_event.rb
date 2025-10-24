module Domain
  module SocialCompetitions
    module Events
      class CompetitionStartedEvent
        attr_reader :aggregate_id, :started_at, :timestamp, :correlation_id

        def initialize(aggregate_id, started_at)
          @aggregate_id = aggregate_id
          @started_at = started_at
          @timestamp = Time.current
          @correlation_id = SecureRandom.uuid
        end

        def to_h
          {
            event_type: self.class.name,
            aggregate_id: aggregate_id,
            started_at: started_at,
            timestamp: timestamp,
            correlation_id: correlation_id
          }
        end
      end
    end
  end
end