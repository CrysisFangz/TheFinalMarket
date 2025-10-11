class CrossChannelJourney < ApplicationRecord
  belongs_to :omnichannel_customer
  belongs_to :sales_channel # Starting channel
  has_many :journey_touchpoints, dependent: :destroy
  
  validates :omnichannel_customer, presence: true
  validates :sales_channel, presence: true
  validates :intent, presence: true
  
  enum intent: {
    browse: 0,
    research: 1,
    purchase: 2,
    support: 3,
    return: 4,
    review: 5
  }
  
  # Add touchpoint to journey
  def add_touchpoint(channel, action, metadata = {})
    touchpoint = journey_touchpoints.create!(
      sales_channel: channel,
      action: action,
      touchpoint_data: metadata,
      occurred_at: Time.current
    )
    
    # Update journey data
    channels = (journey_data['channels'] || []) + [channel.name]
    update!(
      touchpoint_count: touchpoint_count + 1,
      journey_data: journey_data.merge('channels' => channels.uniq),
      last_touchpoint_at: Time.current
    )
    
    touchpoint
  end
  
  # Complete journey
  def complete!(outcome = 'success')
    update!(
      completed: true,
      completed_at: Time.current,
      outcome: outcome,
      duration_seconds: (Time.current - started_at).to_i
    )
  end
  
  # Abandon journey
  def abandon!
    complete!('abandoned')
  end
  
  # Get journey summary
  def summary
    {
      id: id,
      intent: intent,
      started_at: started_at,
      completed_at: completed_at,
      duration: duration_in_words,
      touchpoints: touchpoint_count,
      channels: journey_data['channels'] || [],
      outcome: outcome,
      completed: completed?
    }
  end
  
  # Get journey path
  def journey_path
    journey_touchpoints.order(:occurred_at).map do |tp|
      "#{tp.sales_channel.name} (#{tp.action})"
    end.join(' → ')
  end
  
  # Calculate journey metrics
  def metrics
    {
      duration_seconds: duration_seconds || (Time.current - started_at).to_i,
      touchpoint_count: touchpoint_count,
      channel_count: (journey_data['channels'] || []).count,
      completed: completed?,
      outcome: outcome,
      conversion_rate: completed? && outcome == 'success' ? 100 : 0
    }
  end
  
  # Check if journey involves multiple channels
  def multi_channel?
    (journey_data['channels'] || []).count > 1
  end
  
  # Get channel sequence
  def channel_sequence
    journey_data['channels'] || []
  end
  
  private
  
  def duration_in_words
    return 'In progress' unless completed?
    
    seconds = duration_seconds
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    
    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end
end

