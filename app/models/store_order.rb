# app/models/store_order.rb
class StoreOrder < ApplicationRecord
  belongs_to :user
  belongs_to :seller, class_name: 'User'
  has_many :order_items, dependent: :destroy

  validates :user_id, :seller_id, :status, :total_amount, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }

  validate :valid_status_transition, on: :update

  after_create :invalidate_revenue_cache
  after_update :publish_status_change_event, if: :status_changed?

  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: 'pending') }

  # Removed monthly_revenue method - extracted to RevenueCalculator service

  enum status: {
    pending: 'pending',
    processing: 'processing',
    shipped: 'shipped',
    delivered: 'delivered',
    cancelled: 'cancelled'
  }

  def self.monthly_revenue
    RevenueCalculator.instance.monthly_revenue
  end

  def self.recent_orders(limit: 10)
    RecentOrdersQuery.call(limit: limit)
  end

  def presenter
    StoreOrderPresenter.new(self)
  end

  private

  def valid_status_transition
    return unless status_changed?

    allowed_transitions = {
      'pending' => ['processing', 'cancelled'],
      'processing' => ['shipped', 'cancelled'],
      'shipped' => ['delivered'],
      'delivered' => [], # Final state
      'cancelled' => []  # Final state
    }

    if allowed_transitions[status_was].exclude?(status)
      errors.add(:status, "cannot transition from #{status_was} to #{status}")
    end
  end

  def invalidate_revenue_cache
    RevenueCalculator.instance.invalidate_cache
  end

  def publish_status_change_event
    event = OrderStatusChangedEvent.new(self, status_was, status)
    event.publish
  end
end