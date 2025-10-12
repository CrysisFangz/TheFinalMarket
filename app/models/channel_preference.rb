class ChannelPreference < ApplicationRecord
  belongs_to :omnichannel_customer
  belongs_to :sales_channel
  
  validates :omnichannel_customer, presence: true
  validates :sales_channel, presence: true
  validates :omnichannel_customer_id, uniqueness: { scope: :sales_channel_id }
  
  # Update preferences
  def update_preferences(new_prefs)
    update!(
      preferences_data: (preferences_data || {}).merge(new_prefs),
      last_synced_at: Time.current
    )
  end
  
  # Get specific preference
  def get_preference(key)
    preferences_data&.dig(key)
  end
  
  # Set specific preference
  def set_preference(key, value)
    prefs = preferences_data || {}
    prefs[key] = value
    update!(preferences_data: prefs)
  end
end

