class JourneyTouchpoint < ApplicationRecord
  belongs_to :cross_channel_journey
  belongs_to :sales_channel
  
  validates :cross_channel_journey, presence: true
  validates :sales_channel, presence: true
  validates :action, presence: true
  
  # Get touchpoint summary
  def summary
    {
      channel: sales_channel.name,
      action: action,
      timestamp: occurred_at,
      data: touchpoint_data
    }
  end
end

