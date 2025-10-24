class Domain::SocialCompetitions::CompetitionTeam
  attr_reader :id, :name, :captain, :members, :total_score, :rank

  def initialize(id, name, captain, members, total_score, rank)
    @id = id
    @name = name
    @captain = captain
    @members = members
    @total_score = Domain::SocialCompetitions::Score.new(total_score)
    @rank = Domain::SocialCompetitions::Rank.new(rank)
  end

  def add_member(user)
    return false if full?
    return false if @members.include?(user)
    @members << user
    true
  end

  def remove_member(user)
    return false if user == @captain
    @members.delete(user)
  end

  def full?
    return false unless max_members
    @members.count >= max_members
  end

  def recalculate_score!
    @total_score = Domain::SocialCompetitions::Score.new(@members.sum(&:score))
  end

  def team_stats
    {
      name: @name,
      captain: @captain.username,
      members_count: @members.count,
      total_score: @total_score.to_i,
      average_score: average_member_score,
      rank: @rank.to_i
    }
  end

  private

  def average_member_score
    return 0 if @members.count.zero?
    (@total_score.to_f / @members.count).round(2)
  end

  def max_members
    # Assuming max_members is defined somewhere, e.g., in the model
    10 # Placeholder
  end
end