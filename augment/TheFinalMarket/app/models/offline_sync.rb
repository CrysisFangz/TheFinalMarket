class OfflineSync < ApplicationRecord
  belongs_to :user
  belongs_to :mobile_device
  
  validates :user, presence: true
  validates :mobile_device, presence: true
  validates :sync_type, presence: true
  
  enum sync_type: {
    cart: 0,
    wishlist: 1,
    product_view: 2,
    search: 3,
    order: 4,
    review: 5,
    settings: 6
  }
  
  enum sync_status: {
    pending: 0,
    syncing: 1,
    completed: 2,
    failed: 3,
    conflict: 4
  }
  
  # Scopes
  scope :pending_syncs, -> { where(sync_status: :pending) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_device, ->(device) { where(mobile_device: device) }
  
  # Queue offline action for sync
  def self.queue_action(user, device, sync_type, action_data)
    create!(
      user: user,
      mobile_device: device,
      sync_type: sync_type,
      action_data: action_data,
      sync_status: :pending,
      queued_at: Time.current
    )
  end
  
  # Process sync
  def process!
    update!(sync_status: :syncing, sync_started_at: Time.current)
    
    begin
      result = execute_sync_action
      
      if result[:success]
        update!(
          sync_status: :completed,
          sync_completed_at: Time.current,
          sync_result: result[:data]
        )
      else
        handle_sync_failure(result[:error])
      end
    rescue => e
      handle_sync_failure(e.message)
    end
  end
  
  # Process all pending syncs for user
  def self.process_pending_for_user(user, device)
    pending_syncs.where(user: user, mobile_device: device).find_each do |sync|
      sync.process!
    end
  end
  
  # Get sync statistics
  def self.statistics(user)
    {
      total_syncs: where(user: user).count,
      pending: where(user: user, sync_status: :pending).count,
      completed: where(user: user, sync_status: :completed).count,
      failed: where(user: user, sync_status: :failed).count,
      conflicts: where(user: user, sync_status: :conflict).count
    }
  end
  
  private
  
  def execute_sync_action
    case sync_type.to_sym
    when :cart
      sync_cart_action
    when :wishlist
      sync_wishlist_action
    when :product_view
      sync_product_view_action
    when :search
      sync_search_action
    when :order
      sync_order_action
    when :review
      sync_review_action
    when :settings
      sync_settings_action
    else
      { success: false, error: 'Unknown sync type' }
    end
  end
  
  def sync_cart_action
    case action_data['action']
    when 'add_item'
      cart = user.cart || user.create_cart!
      product = Product.find(action_data['product_id'])
      cart.add_item(product, action_data['quantity'] || 1)
      { success: true, data: { cart_id: cart.id } }
    when 'remove_item'
      cart = user.cart
      cart&.remove_item(action_data['product_id'])
      { success: true, data: { cart_id: cart&.id } }
    else
      { success: false, error: 'Unknown cart action' }
    end
  end
  
  def sync_wishlist_action
    case action_data['action']
    when 'add_item'
      wishlist = user.wishlist || user.create_wishlist!
      product = Product.find(action_data['product_id'])
      wishlist.add_item(product)
      { success: true, data: { wishlist_id: wishlist.id } }
    when 'remove_item'
      wishlist = user.wishlist
      wishlist&.remove_item(action_data['product_id'])
      { success: true, data: { wishlist_id: wishlist&.id } }
    else
      { success: false, error: 'Unknown wishlist action' }
    end
  end
  
  def sync_product_view_action
    product = Product.find(action_data['product_id'])
    ProductView.create!(
      user: user,
      product: product,
      viewed_at: action_data['viewed_at'] || Time.current
    )
    { success: true, data: { product_id: product.id } }
  end
  
  def sync_search_action
    # Log search query
    { success: true, data: { query: action_data['query'] } }
  end
  
  def sync_order_action
    # Handle offline order creation
    { success: true, data: { order_id: action_data['order_id'] } }
  end
  
  def sync_review_action
    product = Product.find(action_data['product_id'])
    review = Review.create!(
      user: user,
      product: product,
      rating: action_data['rating'],
      comment: action_data['comment']
    )
    { success: true, data: { review_id: review.id } }
  end
  
  def sync_settings_action
    user.update!(action_data['settings'])
    { success: true, data: { updated: true } }
  end
  
  def handle_sync_failure(error_message)
    increment!(:retry_count)
    
    if retry_count >= 3
      update!(
        sync_status: :failed,
        error_message: error_message,
        sync_completed_at: Time.current
      )
    else
      update!(
        sync_status: :pending,
        error_message: error_message
      )
    end
  end
end

