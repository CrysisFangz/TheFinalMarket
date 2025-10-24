class Domain::SocialCompetitions::Rank
  attr_reader :value

  def initialize(value)
    @value = value.to_i
  end

  def ==(other)
    @value == other.value
  end

  def to_i
    @value
  end

  def ordinalize
    case @value
    when 1 then "1st"
    when 2 then "2nd"
    when 3 then "3rd"
    else "#{@value}th"
    end
  end
end