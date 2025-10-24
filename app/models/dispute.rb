class Dispute < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :order
  belongs_to :buyer, class_name: 'User'
  belongs_to :seller, class_name: 'User'
  belongs_to :moderator, class_name: 'User', optional: true
  belongs_to :escrow_transaction, optional: true

  has_many :comments, class_name: 'DisputeComment', dependent: :destroy
  has_many :evidences, class_name: 'DisputeEvidence', dependent: :destroy
  has_one :resolution, class_name: 'DisputeResolution', dependent: :destroy

  enum status: {
    pending: 0,
    under_review: 1,
    resolved: 2,
    dismissed: 3,
    refunded: 4,
    partially_refunded: 5
  }

  enum dispute_type: {
    non_delivery: 0,
    quality_issues: 1,
    not_as_described: 2,
    damaged_in_transit: 3,
    other: 4
  }

  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :description, presence: true, length: { minimum: 20, maximum: 1000 }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :dispute_type, presence: true

  scope :unassigned, -> { where(moderator: nil) }
  scope :active, -> { where.not(status: [:resolved, :dismissed, :refunded, :partially_refunded]) }
  scope :needs_review, -> { where(status: :under_review) }
  scope :pending_resolution, -> { where(status: [:pending, :under_review]) }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def assign_to_moderator(moderator)
    DisputeManagementService.assign_to_moderator(self, moderator)
  end

  def resolve(resolution_params)
    DisputeResolutionService.resolve(self, resolution_params)
  end

  def add_evidence(user, evidence_params)
    DisputeEvidenceService.add_evidence(self, user, evidence_params)
  end

  def can_participate?(user)
    Rails.cache.fetch("dispute:#{id}:can_participate:#{user.id}", expires_in: 5.minutes) do
      [buyer_id, seller_id, moderator_id].include?(user.id)
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('dispute.created', {
      dispute_id: id,
      order_id: order_id,
      buyer_id: buyer_id,
      seller_id: seller_id,
      amount: amount,
      dispute_type: dispute_type,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('dispute.updated', {
      dispute_id: id,
      order_id: order_id,
      buyer_id: buyer_id,
      seller_id: seller_id,
      status: status,
      moderator_id: moderator_id,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('dispute.destroyed', {
      dispute_id: id,
      order_id: order_id,
      buyer_id: buyer_id,
      seller_id: seller_id
    })
  end
end