class Review < ApplicationRecord
  include ContentFilterable

  # Associations
  belongs_to :reviewer, class_name: 'User'
  belongs_to :reviewable, polymorphic: true
  belongs_to :review_invitation, optional: true
  belongs_to :order, optional: true
  has_many :helpful_votes, dependent: :destroy
  has_one :dispute, through: :order

  # Validations
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :content, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :pros, length: { maximum: 500 }
  validates :cons, length: { maximum: 500 }
  validates :reviewer_id, uniqueness: { 
    scope: [:reviewable_type, :reviewable_id],
    message: "can only review once"
  }
  validate :validate_moderation_rules

  # Callbacks
  after_create :trigger_post_create_operations
  after_create_commit :trigger_notification_operations

  # Scopes
  scope :for_items, -> { where(reviewable_type: 'Item') }
  scope :for_sellers, -> { where(reviewable_type: 'User') }
  scope :helpful, -> { where('helpful_count > 0') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_rating, -> { order(rating: :desc) }

  def helpful!(user)
    ReviewManagementService.mark_helpful(self, user)
  end

  def unhelpful!(user)
    ReviewManagementService.mark_unhelpful(self, user)
  end

  private

  def filtered_fields
    [:content]
  end

  def item_review?
    reviewable_type == 'Item'
  end

  def seller_review?
    reviewable_type == 'User'
  end

  def self.cached_find(id)
    Rails.cache.fetch("review:#{id}", expires_in: 30.minutes) do
      find_by(id: id)
    end
  end

  def self.cached_for_reviewable(reviewable_type, reviewable_id)
    Rails.cache.fetch("reviews:#{reviewable_type}:#{reviewable_id}", expires_in: 15.minutes) do
      where(reviewable_type: reviewable_type, reviewable_id: reviewable_id).includes(:reviewer).to_a
    end
  end

  def self.cached_helpful_count(review_id)
    Rails.cache.fetch("review_helpful_count:#{review_id}", expires_in: 10.minutes) do
      find(review_id).helpful_count
    end
  end

  def presenter
    @presenter ||= ReviewPresenter.new(self)
  end

  private

  def validate_moderation_rules
    ReviewModerationService.moderate_review(self)
  end

  def trigger_post_create_operations
    ReviewRatingService.update_reviewable_rating(self)
    ReviewRatingService.award_review_points(self)
  end

  def trigger_notification_operations
    ReviewNotificationService.notify_owner(self)
    ReviewNotificationService.notify_mentioned_users(self)
  end

  def clear_review_cache
    ReviewManagementService.clear_review_cache(id)
    ReviewRatingService.clear_rating_cache(reviewable_type, reviewable_id)
    ReviewNotificationService.clear_notification_cache(id)
    ReviewModerationService.clear_moderation_cache(id)

    # Clear related caches
    Rails.cache.delete("review:#{id}")
    Rails.cache.delete("reviews:#{reviewable_type}:#{reviewable_id}")
    Rails.cache.delete("review_helpful_count:#{id}")
  end

  def publish_created_event
    EventPublisher.publish('review.created', {
      review_id: id,
      reviewer_id: reviewer_id,
      reviewable_type: reviewable_type,
      reviewable_id: reviewable_id,
      rating: rating,
      helpful_count: helpful_count,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('review.updated', {
      review_id: id,
      reviewer_id: reviewer_id,
      reviewable_type: reviewable_type,
      reviewable_id: reviewable_id,
      rating: rating,
      helpful_count: helpful_count,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('review.destroyed', {
      review_id: id,
      reviewer_id: reviewer_id,
      reviewable_type: reviewable_type,
      reviewable_id: reviewable_id,
      rating: rating,
      helpful_count: helpful_count
    })
  end
end