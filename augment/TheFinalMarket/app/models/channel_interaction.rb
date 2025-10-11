class ChannelInteraction < ApplicationRecord
  belongs_to :omnichannel_customer
  belongs_to :sales_channel
  
  validates :omnichannel_customer, presence: true
  validates :sales_channel, presence: true
  validates :interaction_type, presence: true
  
  enum interaction_type: {
    page_view: 0,
    product_view: 1,
    search: 2,
    add_to_cart: 3,
    remove_from_cart: 4,
    checkout_start: 5,
    checkout_complete: 6,
    cart_abandonment: 7,
    wishlist_add: 8,
    review_submit: 9,
    customer_service: 10,
    email_open: 11,
    email_click: 12,
    social_engagement: 13,
    store_visit: 14,
    phone_call: 15
  }
  
  # Scopes
  scope :recent, -> { where('occurred_at > ?', 30.days.ago) }
  scope :by_channel, ->(channel) { where(sales_channel: channel) }
  scope :by_type, ->(type) { where(interaction_type: type) }
  
  # Get interaction value score
  def value_score
    case interaction_type.to_sym
    when :checkout_complete
      100
    when :checkout_start
      75
    when :add_to_cart
      50
    when :product_view
      25
    when :wishlist_add
      30
    when :review_submit
      40
    when :customer_service
      20
    when :email_click
      15
    when :social_engagement
      10
    when :page_view, :search
      5
    else
      0
    end
  end
  
  # Check if high-value interaction
  def high_value?
    value_score >= 50
  end
  
  # Get interaction context
  def context
    {
      channel: sales_channel.name,
      type: interaction_type,
      timestamp: occurred_at,
      data: interaction_data,
      value_score: value_score
    }
  end
end

