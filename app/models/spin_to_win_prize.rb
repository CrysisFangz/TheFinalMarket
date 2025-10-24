class SpinToWinPrize < ApplicationRecord
  belongs_to :spin_to_win
  has_many :spin_to_win_spins
  
  validates :spin_to_win, presence: true
  validates :prize_name, presence: true
  validates :prize_type, presence: true
  validates :probability, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  
  enum prize_type: {
    coins: 0,
    discount_code: 1,
    free_shipping: 2,
    product: 3,
    experience_points: 4,
    loyalty_tokens: 5,
    mystery_box: 6
  }
  
  
  
    # Get times won - using counter cache for performance
  def times_won
    times_won_count || 0
  end

  # Presenter for display logic
  def presenter
    @presenter ||= SpinToWinPrizePresenter.new(self)
  end

  # Scopes for query optimization
  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(prize_type: type) }
  scope :high_probability, -> { where('probability > 50') }
  scope :ordered_by_probability, -> { order(probability: :desc) }
  scope :with_spin_to_win, -> { includes(:spin_to_win) }
  scope :with_spins, -> { includes(:spin_to_win_spins) }
  scope :most_won, -> { order(times_won_count: :desc) }

    # Additional validations
  validates :prize_value, presence: true, numericality: { greater_than: 0 }, if: -> { prize_type.in?([:coins, :discount_code, :experience_points, :loyalty_tokens]) }
  validates :active, inclusion: { in: [true, false] }
  validate :probabilities_sum_to_100, on: :create

  # Method to recalculate times_won (for maintenance)
  def recalculate_times_won!
    update!(times_won_count: spin_to_win_spins.count)
  end

  private

  def probabilities_sum_to_100
    return unless spin_to_win

    total_probability = spin_to_win.spin_to_win_prizes.sum(:probability)
    if total_probability != 100
      errors.add(:probability, "sum must be 100 for all prizes in the spin_to_win")
    end
  end</search>
</search_and_replace>
end</search>
</search_and_replace>

