class AddTimesWonToSpinToWinPrizes < ActiveRecord::Migration[8.0]
  def change
    add_column :spin_to_win_prizes, :times_won, :integer, default: 0, null: false
    add_index :spin_to_win_prizes, :times_won
  end
end