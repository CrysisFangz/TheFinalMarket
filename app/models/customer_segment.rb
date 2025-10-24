class CustomerSegment < ApplicationRecord
  include CircuitBreaker

  has_many :customer_segment_members, dependent: :destroy
  has_many :users, through: :customer_segment_members

  validates :name, presence: true
  validates :segment_type, presence: true

  scope :active, -> { where(active: true) }
  scope :auto_segments, -> { where(auto_update: true) }

  enum segment_type: {
    behavioral: 0,
    demographic: 1,
    rfm: 2,
    value_based: 3,
    engagement: 4,
    custom: 9
  }

  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def update_members!
    with_retry do
      CustomerSegmentService.new.update_members(self)
    end
  end

  def statistics
    Rails.cache.fetch("segment:#{id}:statistics", expires_in: 1.hour) do
      {
        member_count: users.count,
        total_revenue: users.joins(:orders).where(orders: { status: 'completed' }).sum('orders.total_cents'),
        avg_order_value: users.joins(:orders).where(orders: { status: 'completed' }).average('orders.total_cents'),
        total_orders: users.joins(:orders).where(orders: { status: 'completed' }).count,
        avg_orders_per_customer: users.joins(:orders).where(orders: { status: 'completed' }).count / [users.count, 1].max.to_f
      }
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('customer_segment.created', { segment_id: id, name: name })
  end

  def publish_updated_event
    EventPublisher.publish('customer_segment.updated', { segment_id: id, name: name })
  end

  def publish_destroyed_event
    EventPublisher.publish('customer_segment.destroyed', { segment_id: id, name: name })
  end

  def with_retry(max_retries: 3, &block)
    retries = 0
    begin
      yield
    rescue StandardError => e
      retries += 1
      retry if retries < max_retries
      Rails.logger.error("Failed after #{retries} retries: #{e.message}")
      raise e
    end
  end
end

