class ChannelAnalytics < ApplicationRecord
  belongs_to :sales_channel
  
  validates :sales_channel, presence: true
  validates :date, presence: true
  validates :date, uniqueness: { scope: :sales_channel_id }
  
  # Record daily analytics
  def self.record_for_channel(channel, date = Date.current)
    analytics = find_or_initialize_by(sales_channel: channel, date: date)
    
    orders = channel.orders.where('DATE(created_at) = ?', date)
    
    analytics.assign_attributes(
      orders_count: orders.count,
      revenue: orders.where(status: 'completed').sum(:total),
      average_order_value: orders.where(status: 'completed').average(:total).to_f.round(2),
      unique_customers: orders.distinct.count(:user_id),
      new_customers: orders.joins(:user).where('users.created_at >= ?', date.beginning_of_day).distinct.count(:user_id),
      returning_customers: orders.joins(:user).where('users.created_at < ?', date.beginning_of_day).distinct.count(:user_id),
      conversion_rate: calculate_conversion_rate(channel, date),
      return_rate: calculate_return_rate(orders),
      units_sold: orders.joins(:order_items).sum('order_items.quantity')
    )
    
    analytics.save!
    analytics
  end
  
  # Get trend data
  def self.trend_data(channel, days: 30)
    where(sales_channel: channel)
      .where('date >= ?', days.days.ago.to_date)
      .order(:date)
      .pluck(:date, :revenue, :orders_count, :conversion_rate)
  end
  
  private
  
  def self.calculate_conversion_rate(channel, date)
    # Mock calculation - would integrate with actual traffic data
    rand(1.0..5.0).round(2)
  end
  
  def self.calculate_return_rate(orders)
    return 0 if orders.empty?
    returned = orders.where(status: 'returned').count
    ((returned.to_f / orders.count) * 100).round(2)
  end
end

