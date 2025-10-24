class Domain::SocialCompetitions::CompetitionParticipant
  attr_reader :id, :user, :competition_team, :score, :rank, :registered_at

  def initialize(id, user, competition_team, score, rank, registered_at)
    @id = id
    @user = user
    @competition_team = competition_team
    @score = Domain::SocialCompetitions::Score.new(score)
    @rank = Domain::SocialCompetitions::Rank.new(rank)
    @registered_at = registered_at
  end

  def update_score(new_score)
    @score = Domain::SocialCompetitions::Score.new(new_score)
  end

  def update_rank(new_rank)
    @rank = Domain::SocialCompetitions::Rank.new(new_rank)
  end

  def performance_stats
    {
      score: @score.to_i,
      rank: @rank.to_i,
      team: @competition_team&.name,
      registered_at: @registered_at,
      time_in_competition: time_in_competition
    }
  end

  private

  def time_in_competition
    return 0 unless @competition.started_at
    end_time = @competition.ended_at || Time.current
    ((end_time - @competition.started_at) / 1.day).round(1)
  end
end