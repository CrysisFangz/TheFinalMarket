# frozen_string_literal: true

# ProductView model refactored for performance and data management.
# Tracks user product viewing history with automatic cleanup.
class ProductView < ApplicationRecord
  belongs_to :user
  belongs_to :product

  # Enhanced validations with custom messages
  validates :user_id, presence: true
  validates :product_id, presence: true
  validates :user_id, uniqueness: { scope: :product_id, message: "already has a view record for this product" }

  # Event-driven: Publish events on view creation
  after_create :publish_view_created_event
  after_create :schedule_cleanup

  # Scopes for optimized queries
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_product, ->(product_id) { where(product_id: product_id) }
  scope :with_associations, -> { includes(:user, :product) }

  private

  def schedule_cleanup
    ProductViewCleanupService.cleanup_after_view_creation(self)
  end

  def publish_view_created_event
    Rails.logger.info("Product view created: User=#{user_id}, Product=#{product_id}")
    # In a full event system: EventPublisher.publish('product_viewed', self.attributes)
  end
end