class SpinToWin < ApplicationRecord
  has_many :spin_to_win_prizes, dependent: :destroy
  has_many :spin_to_win_spins, dependent: :destroy

  validates :name, presence: true
  validates :status, presence: true
  validates :spins_per_user_per_day, numericality: { greater_than: 0 }

  enum status: {
    inactive: 0,
    active: 1,
    paused: 2
  }

  # Scopes
  scope :active_wheels, -> { where(status: :active) }

  # Optimized indexes
  index :status
  index :name
end

