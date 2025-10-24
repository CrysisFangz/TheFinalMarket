module Domain
  module SocialCompetitions
    module Infrastructure
      class EventPublisher
        def publish(event)
          # In a real system, this would publish to a message queue or event store
          # For now, just log it
          Rails.logger.info("Event published: #{event.event_type} - #{event.to_h}")
        end
      end
    end
  end
end