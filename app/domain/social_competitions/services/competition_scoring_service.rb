module Domain
  module SocialCompetitions
    module Services
      class CompetitionScoringService
        def initialize(participant_repository, team_repository)
          @participant_repository = participant_repository
          @team_repository = team_repository
        end

        def update_score(competition_id, user_id, points)
          participant = @participant_repository.find_by_user_and_competition(user_id, competition_id)
          return unless participant

          participant.increment!(:score, points)

          if participant.team?
            team = @team_repository.find(participant.competition_team_id)
            team.recalculate_score!
          end

          update_rankings(competition_id)
        end

        private

        def update_rankings(competition_id)
          participants = @participant_repository.for_competition(competition_id).order(score: :desc, registered_at: :asc)
          participants.each.with_index(1) do |p, index|
            p.update_column(:rank, index)
          end
        end
      end
    end
  end
end