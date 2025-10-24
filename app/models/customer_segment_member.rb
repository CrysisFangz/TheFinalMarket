class CustomerSegmentMember < ApplicationRecord
  include CircuitBreaker

  belongs_to :customer_segment
  belongs_to :user

  validates :user_id, uniqueness: { scope: :customer_segment_id }

  scope :active, -> { where(active: true) }
  scope :for_segment, ->(segment_id) { where(customer_segment_id: segment_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  after_create :publish_created_event
  after_destroy :publish_destroyed_event

  def publish_created_event
    EventPublisher.publish('customer_segment_member.created', { member_id: id, user_id: user_id, segment_id: customer_segment_id })
  end

  def publish_destroyed_event
    EventPublisher.publish('customer_segment_member.destroyed', { member_id: id, user_id: user_id, segment_id: customer_segment_id })
  end
end

