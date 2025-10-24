class CompleteHuntService
  def initialize(participation)
    @participation = participation
  end

  def call
    ActiveRecord::Base.transaction do
      time_taken = calculate_time_taken
      rank = RankCalculator.new(participation).call

      participation.update!(
        completed: true,
        completed_at: Time.current,
        time_taken_seconds: time_taken,
        rank: rank
      )

      RewardCalculator.new(participation).call
    end
  end

  private

  attr_reader :participation

  def calculate_time_taken
    (Time.current - participation.started_at).to_i
  end
end