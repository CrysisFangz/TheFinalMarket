module Domain
  module SocialCompetitions
    module Presenters
      class LeaderboardPresenter
        def initialize(leaderboard_data)
          @leaderboard_data = leaderboard_data
        end

        def as_json
          @leaderboard_data.map do |entry|
            if entry[:team]
              {
                rank: entry[:rank],
                team: entry[:team].name,
                score: entry[:score],
                members: entry[:members],
                prize: entry[:prize]
              }
            else
              {
                rank: entry[:rank],
                user: entry[:user]&.username,
                score: entry[:score],
                prize: entry[:prize]
              }
            end
          end
        end

        def as_csv
          CSV.generate do |csv|
            csv << ['Rank', 'User/Team', 'Score', 'Prize']
            @leaderboard_data.each do |entry|
              name = entry[:team] ? entry[:team].name : entry[:user]&.username
              csv << [entry[:rank], name, entry[:score], entry[:prize]]
            end
          end
        end
      end
    end
  end
end