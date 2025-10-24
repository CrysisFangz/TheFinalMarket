class Domain::SocialCompetitions::Score
  attr_reader :value

  def initialize(value)
    @value = value.to_i
  end

  def +(other)
    self.class.new(@value + other.value)
  end

  def -(other)
    self.class.new(@value - other.value)
  end

  def ==(other)
    @value == other.value
  end

  def to_i
    @value
  end

  def to_f
    @value.to_f
  end
end