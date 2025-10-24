module Domain
  module SocialCompetitions
    module Repositories
      class CompetitionRepository
        def find(id)
          ::SocialCompetition.find(id)
        end

        def find_by_status(status)
          ::SocialCompetition.where(status: status)
        end

        def active_competitions
          ::SocialCompetition.active_competitions
        end

        def open_for_registration
          ::SocialCompetition.open_for_registration
        end
      end
    end
  end
end