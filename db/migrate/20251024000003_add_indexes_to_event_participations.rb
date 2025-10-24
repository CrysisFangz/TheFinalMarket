class AddIndexesToEventParticipations < ActiveRecord::Migration[7.0]
  def change
    add_index :event_participations, :seasonal_event_id
    add_index :event_participations, [:seasonal_event_id, :points, :joined_at]
    add_index :event_participations, [:seasonal_event_id, :user_id], unique: true
    add_index :event_participations, :points
    add_index :event_participations, :rank
  end
end