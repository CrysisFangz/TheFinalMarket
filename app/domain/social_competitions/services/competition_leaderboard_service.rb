module Domain
  module SocialCompetitions
    module Services
      class CompetitionLeaderboardService
        def initialize(participant_repository, team_repository, presenter_class)
          @participant_repository = participant_repository
          @team_repository = team_repository
          @presenter_class = presenter_class
        end

        def leaderboard(competition_id, limit)
          competition = ::SocialCompetition.find(competition_id)
          if competition.team?
            team_leaderboard(competition_id, limit)
          else
            individual_leaderboard(competition_id, limit)
          end
        end

        def calculate_final_rankings(competition_id)
          participants = @participant_repository.for_competition(competition_id).order(score: :desc, registered_at: :asc)
          participants.each.with_index(1) do |p, index|
            p.update_column(:rank, index)
          end
        end

        private

        def individual_leaderboard(competition_id, limit)
          data = @participant_repository.for_competition(competition_id)
                                        .order(score: :desc, registered_at: :asc)
                                        .limit(limit)
                                        .includes(:user)
                                        .map.with_index(1) do |participant, index|
            {
              rank: index,
              user: participant.user,
              score: participant.score,
              prize: calculate_prize(competition_id, index)
            }
          end
          @presenter_class.new(data).as_json
        end

        def team_leaderboard(competition_id, limit)
          data = @team_repository.where(social_competition_id: competition_id)
                                 .order(total_score: :desc, created_at: :asc)
                                 .limit(limit)
                                 .map.with_index(1) do |team, index|
            {
              rank: index,
              team: team,
              score: team.total_score,
              members: team.members.count,
              prize: calculate_prize(competition_id, index)
            }
          end
          @presenter_class.new(data).as_json
        end

        def calculate_prize(competition_id, rank)
          competition = ::SocialCompetition.find(competition_id)
          return 0 unless competition.prize_pool > 0

          case rank
          when 1
            (competition.prize_pool * 0.5).to_i
          when 2
            (competition.prize_pool * 0.3).to_i
          when 3
            (competition.prize_pool * 0.2).to_i
          else
            0
          end
        end
      end
    end
  end
end