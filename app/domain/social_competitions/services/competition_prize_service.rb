module Domain
  module SocialCompetitions
    module Services
      class CompetitionPrizeService
        def initialize(user_model, notification_model, competition_model)
          @user_model = user_model
          @notification_model = notification_model
          @competition_model = competition_model
        end

        def award_prizes(competition_id)
          competition = @competition_model.find(competition_id)
          leaderboard = competition.leaderboard(limit: competition.prize_positions || 3)
          leaderboard.each do |entry|
            next unless entry[:prize] > 0

            if competition.team?
              award_team_prize(entry[:team], entry[:prize])
            else
              award_individual_prize(entry[:user], entry[:prize], entry[:rank])
            end
          end
        end

        private

        def award_individual_prize(user, prize, rank)
          @user_model.find(user.id).increment!(:coins, prize)

          @notification_model.create!(
            recipient: user,
            notifiable: @competition_model.find(user.social_competition_id),
            notification_type: 'competition_prize',
            title: "Competition Prize!",
            message: "You finished #{rank.ordinalize} in #{@competition_model.find(user.social_competition_id).name}!",
            data: { rank: rank, prize: prize }
          )
        end

        def award_team_prize(team, prize)
          prize_per_member = (prize / team.members.count.to_f).to_i

          team.members.each do |member|
            @user_model.find(member.id).increment!(:coins, prize_per_member)

            @notification_model.create!(
              recipient: member,
              notifiable: @competition_model.find(team.social_competition_id),
              notification_type: 'competition_prize',
              title: "Team Competition Prize!",
              message: "Your team won #{prize} coins in #{@competition_model.find(team.social_competition_id).name}!",
              data: { team_prize: prize, individual_share: prize_per_member }
            )
          end
        end
      end
    end
  end
end