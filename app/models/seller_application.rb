class SellerApplication < ApplicationRecord
  belongs_to :user
  belongs_to :reviewed_by, class_name: 'User', optional: true

  enum status: {
    pending: 'pending',
    approved: 'approved',
    rejected: 'rejected'
  }

  validates :note, presence: true, length: { minimum: 50, maximum: 2000 }
  validates :user_id, uniqueness: { message: "already has a pending or approved application" }
  validate :user_is_not_already_a_seller

  after_create :process_creation
  after_update :process_status_change

  private

  def user_is_not_already_a_seller
    if user.gem?
      errors.add(:user, "is already a Gem (seller)")
    end
  end

  def process_creation
    SellerApplicationService.new(self).process_creation
  end

  def process_status_change
    SellerApplicationService.new(self).process_status_change if saved_change_to_status?
  end
end
