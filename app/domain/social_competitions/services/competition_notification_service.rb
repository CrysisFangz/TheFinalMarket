module Domain
  module SocialCompetitions
    module Services
      class CompetitionNotificationService
        def initialize(notification_model, competition_model)
          @notification_model = notification_model
          @competition_model = competition_model
        end

        def notify_participants(competition_id, message)
          competition = @competition_model.find(competition_id)
          competition.participants.find_each do |user|
            @notification_model.create!(
              recipient: user,
              notifiable: competition,
              notification_type: 'competition_update',
              title: competition.name,
              message: message
            )
          end
        end
      end
    end
  end
end