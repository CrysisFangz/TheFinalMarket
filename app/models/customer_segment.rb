class CustomerSegment < ApplicationRecord
  has_many :customer_segment_members, dependent: :destroy
  has_many :users, through: :customer_segment_members
  
  validates :name, presence: true
  validates :segment_type, presence: true
  
  scope :active, -> { where(active: true) }
  scope :auto_segments, -> { where(auto_update: true) }
  
  # Segment types
  enum segment_type: {
    behavioral: 0,
    demographic: 1,
    rfm: 2,
    value_based: 3,
    engagement: 4,
    custom: 9
  }
  
  # Update segment members
  def update_members!
    case segment_type.to_sym
    when :rfm
      update_rfm_segment
    when :value_based
      update_value_segment
    when :engagement
      update_engagement_segment
    when :behavioral
      update_behavioral_segment
    when :custom
      update_custom_segment
    end
    
    update!(last_updated_at: Time.current, member_count: users.count)
  end
  
  # Get segment statistics
  def statistics
    {
      member_count: users.count,
      total_revenue: users.joins(:orders).where(orders: { status: 'completed' }).sum('orders.total_cents'),
      avg_order_value: users.joins(:orders).where(orders: { status: 'completed' }).average('orders.total_cents'),
      total_orders: users.joins(:orders).where(orders: { status: 'completed' }).count,
      avg_orders_per_customer: users.joins(:orders).where(orders: { status: 'completed' }).count / [users.count, 1].max.to_f
    }
  end
  
  private
  
  def update_rfm_segment
    # RFM: Recency, Frequency, Monetary
    criteria = criteria_config
    
    user_ids = User.joins(:orders)
                   .where(orders: { status: 'completed' })
                   .group('users.id')
                   .having('MAX(orders.created_at) > ?', criteria['recency_days'].days.ago)
                   .having('COUNT(orders.id) >= ?', criteria['min_frequency'])
                   .having('SUM(orders.total_cents) >= ?', criteria['min_monetary'])
                   .pluck('users.id')
    
    sync_members(user_ids)
  end
  
  def update_value_segment
    criteria = criteria_config
    
    user_ids = User.joins(:orders)
                   .where(orders: { status: 'completed' })
                   .group('users.id')
                   .having('SUM(orders.total_cents) >= ?', criteria['min_value'])
                   .pluck('users.id')
    
    sync_members(user_ids)
  end
  
  def update_engagement_segment
    criteria = criteria_config
    
    user_ids = User.where('sign_in_count >= ?', criteria['min_logins'])
                   .where('last_sign_in_at > ?', criteria['active_days'].days.ago)
                   .pluck(:id)
    
    sync_members(user_ids)
  end
  
  def update_behavioral_segment
    # Custom behavioral logic based on criteria
    user_ids = []
    sync_members(user_ids)
  end
  
  def update_custom_segment
    # Execute custom SQL query if provided
    if criteria_config['sql_query'].present?
      user_ids = User.connection.select_values(criteria_config['sql_query'])
      sync_members(user_ids)
    end
  end
  
  def sync_members(user_ids)
    # Remove users no longer in segment
    customer_segment_members.where.not(user_id: user_ids).destroy_all
    
    # Add new users to segment
    user_ids.each do |user_id|
      customer_segment_members.find_or_create_by!(user_id: user_id)
    end
  end
  
  def criteria_config
    criteria || {}
  end
end

