class CustomerSegmentMember < ApplicationRecord
  belongs_to :customer_segment
  belongs_to :user
  
  validates :user_id, uniqueness: { scope: :customer_segment_id }
end

