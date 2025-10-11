class ChannelInventory < ApplicationRecord
  belongs_to :sales_channel
  belongs_to :product
  
  validates :sales_channel, presence: true
  validates :product, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :product_id, uniqueness: { scope: :sales_channel_id }
  
  # Scopes
  scope :in_stock, -> { where('quantity > 0') }
  scope :out_of_stock, -> { where(quantity: 0) }
  scope :low_stock, -> { where('quantity > 0 AND quantity <= reserved_quantity + 10') }
  
  # Sync inventory for a product across all channels
  def self.sync_for_product(product, channel = nil)
    channels = channel ? [channel] : SalesChannel.active_channels
    
    channels.each do |ch|
      inventory = find_or_initialize_by(product: product, sales_channel: ch)
      inventory.quantity = product.stock_quantity
      inventory.last_synced_at = Time.current
      inventory.save!
    end
  end
  
  # Get available quantity (total - reserved)
  def available_quantity
    [quantity - reserved_quantity, 0].max
  end
  
  # Reserve inventory
  def reserve!(amount)
    if available_quantity >= amount
      increment!(:reserved_quantity, amount)
      true
    else
      false
    end
  end
  
  # Release reserved inventory
  def release!(amount)
    decrement!(:reserved_quantity, [amount, reserved_quantity].min)
  end
  
  # Deduct inventory (for completed orders)
  def deduct!(amount)
    if quantity >= amount
      decrement!(:quantity, amount)
      decrement!(:reserved_quantity, [amount, reserved_quantity].min)
      true
    else
      false
    end
  end
  
  # Add inventory
  def add!(amount)
    increment!(:quantity, amount)
  end
  
  # Check if in stock
  def in_stock?
    available_quantity > 0
  end
  
  # Check if low stock
  def low_stock?
    in_stock? && available_quantity <= low_stock_threshold
  end
  
  # Get stock status
  def stock_status
    if available_quantity == 0
      'out_of_stock'
    elsif low_stock?
      'low_stock'
    else
      'in_stock'
    end
  end
  
  # Get inventory alerts
  def alerts
    alerts = []
    
    alerts << {
      type: 'out_of_stock',
      severity: 'critical',
      message: "Product is out of stock on #{sales_channel.name}"
    } if available_quantity == 0
    
    alerts << {
      type: 'low_stock',
      severity: 'warning',
      message: "Low stock on #{sales_channel.name}: #{available_quantity} units remaining"
    } if low_stock?
    
    alerts << {
      type: 'high_reservation',
      severity: 'info',
      message: "High reservation rate: #{reserved_quantity}/#{quantity} reserved"
    } if reserved_quantity > quantity * 0.8
    
    alerts
  end
  
  # Inventory history
  def record_change(change_type, amount, notes = nil)
    InventoryHistory.create!(
      channel_inventory: self,
      change_type: change_type,
      quantity_change: amount,
      quantity_after: quantity,
      reserved_after: reserved_quantity,
      notes: notes
    )
  end
  
  private
  
  def low_stock_threshold
    self[:low_stock_threshold] || 10
  end
end

