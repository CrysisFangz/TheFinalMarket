class Domain::SocialCompetitions::Prize
  attr_reader :amount

  def initialize(amount)
    @amount = amount.to_i
  end

  def ==(other)
    @amount == other.amount
  end

  def to_i
    @amount
  end

  def to_f
    @amount.to_f
  end

  def zero?
    @amount.zero?
  end
end