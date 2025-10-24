# frozen_string_literal: true

# ProductCategory model refactored for data integrity and performance.
# Represents the many-to-many relationship between products and categories.
class ProductCategory < ApplicationRecord
  belongs_to :product
  belongs_to :category

  # Validations for data integrity
  validates :product_id, presence: true, uniqueness: { scope: :category_id, message: "already associated with this category" }
  validates :category_id, presence: true

  # Event-driven: Publish events on creation/deletion
  after_create :publish_category_assigned_event
  after_destroy :publish_category_removed_event

  # Scopes for optimized queries
  scope :by_product, ->(product_id) { where(product_id: product_id) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :with_associations, -> { includes(:product, :category) }

  private

  def publish_category_assigned_event
    Rails.logger.info("Product category assigned: Product=#{product_id}, Category=#{category_id}")
    # In a full event system: EventPublisher.publish('product_category_assigned', self.attributes)
  end

  def publish_category_removed_event
    Rails.logger.info("Product category removed: Product=#{product_id}, Category=#{category_id}")
    # In a full event system: EventPublisher.publish('product_category_removed', self.attributes)
  end
end
