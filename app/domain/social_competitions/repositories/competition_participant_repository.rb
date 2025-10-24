module Domain
  module SocialCompetitions
    module Repositories
      class CompetitionParticipantRepository
        def create(attributes)
          ::CompetitionParticipant.create!(attributes)
        end

        def find_by_user_and_competition(user_id, competition_id)
          ::CompetitionParticipant.find_by(user_id: user_id, social_competition_id: competition_id)
        end

        def for_competition(competition_id)
          ::CompetitionParticipant.where(social_competition_id: competition_id)
        end
      end
    end
  end
end