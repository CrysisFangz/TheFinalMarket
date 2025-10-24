# frozen_string_literal: true

# ProductTag model refactored for data integrity and performance.
# Represents the many-to-many relationship between products and tags.
class ProductTag < ApplicationRecord
  belongs_to :product
  belongs_to :tag

  # Enhanced validations for data integrity
  validates :product_id, presence: true, uniqueness: { scope: :tag_id, message: "already associated with this tag" }
  validates :tag_id, presence: true

  # Event-driven: Publish events on creation/deletion
  after_create :publish_tag_assigned_event
  after_destroy :publish_tag_removed_event

  # Scopes for optimized queries
  scope :by_product, ->(product_id) { where(product_id: product_id) }
  scope :by_tag, ->(tag_id) { where(tag_id: tag_id) }
  scope :with_associations, -> { includes(:product, :tag) }

  private

  def publish_tag_assigned_event
    Rails.logger.info("Product tag assigned: Product=#{product_id}, Tag=#{tag_id}")
    # In a full event system: EventPublisher.publish('product_tag_assigned', self.attributes)
  end

  def publish_tag_removed_event
    Rails.logger.info("Product tag removed: Product=#{product_id}, Tag=#{tag_id}")
    # In a full event system: EventPublisher.publish('product_tag_removed', self.attributes)
  end
end