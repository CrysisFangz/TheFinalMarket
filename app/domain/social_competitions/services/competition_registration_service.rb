module Domain
  module SocialCompetitions
    module Services
      class CompetitionRegistrationService
        def initialize(competition_repository, participant_repository)
          @competition_repository = competition_repository
          @participant_repository = participant_repository
        end

        def register_user(competition_id, user_id, team_id = nil)
          competition = @competition_repository.find(competition_id)
          return false unless competition.can_register?(user_id)

          participant = @participant_repository.create(
            user_id: user_id,
            social_competition_id: competition_id,
            competition_team_id: team_id,
            registered_at: Time.current,
            score: 0
          )

          Domain::SocialCompetitions::Events::ParticipantRegisteredEvent.new(
            competition_id, user_id, team_id
          )
        end
      end
    end
  end
end