class ChannelProduct < ApplicationRecord
  belongs_to :sales_channel
  belongs_to :product
  
  validates :sales_channel, presence: true
  validates :product, presence: true
  validates :product_id, uniqueness: { scope: :sales_channel_id }
  
  # Scopes
  scope :available, -> { where(available: true) }
  scope :unavailable, -> { where(available: false) }
  
  # Get effective price
  def effective_price
    price_override || product.price
  end
  
  # Get effective inventory
  def effective_inventory
    inventory_override || product.stock_quantity
  end
  
  # Check availability
  def available_for_purchase?
    available? && effective_inventory > 0
  end
  
  # Update channel-specific data
  def update_channel_data(data)
    update!(channel_specific_data: (channel_specific_data || {}).merge(data))
  end
  
  # Get channel-specific attributes
  def channel_title
    channel_specific_data&.dig('title') || product.name
  end
  
  def channel_description
    channel_specific_data&.dig('description') || product.description
  end
  
  def channel_images
    channel_specific_data&.dig('images') || []
  end
  
  # Sync from product
  def sync_from_product!
    update!(
      available: product.active?,
      inventory_override: nil, # Use product's inventory
      last_synced_at: Time.current
    )
  end
  
  # Performance metrics
  def performance_metrics(days: 30)
    start_date = days.days.ago
    
    # Get orders containing this product on this channel
    order_items = OrderItem.joins(:order)
                           .where(product: product)
                           .where(orders: { sales_channel: sales_channel })
                           .where('orders.created_at > ?', start_date)
    
    {
      units_sold: order_items.sum(:quantity),
      revenue: order_items.sum('quantity * price'),
      orders_count: order_items.distinct.count(:order_id),
      average_price: order_items.average(:price).to_f.round(2),
      return_count: order_items.joins(:order).where(orders: { status: 'returned' }).count
    }
  end
end

