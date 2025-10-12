class SpinToWinSpin < ApplicationRecord
  belongs_to :spin_to_win
  belongs_to :user
  belongs_to :spin_to_win_prize
  
  validates :spin_to_win, presence: true
  validates :user, presence: true
  validates :spin_to_win_prize, presence: true
  validates :spun_at, presence: true
end

