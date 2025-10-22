class SpinToWinSpin < ApplicationRecord
  belongs_to :spin_to_win
  belongs_to :user
  belongs_to :spin_to_win_prize

  validates :spin_to_win, presence: true
  validates :user, presence: true
  validates :spin_to_win_prize, presence: true
  validates :spun_at, presence: true

  # Optimized indexes for performance
  index :user_id
  index :spin_to_win_id
  index :spun_at
  index [:user_id, :spun_at]
  index [:spin_to_win_id, :spun_at]
end

