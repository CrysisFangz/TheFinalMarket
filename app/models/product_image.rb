# frozen_string_literal: true

# ProductImage model refactored for performance and resilience.
# Image processing logic extracted into dedicated services.
class ProductImage < ApplicationRecord
  belongs_to :product
  has_one_attached :image
  has_one_attached :thumbnail

  # Enhanced validations with custom messages
  validates :image, presence: true
  validates :thumbnail, allow_nil: true
  validate :validate_image_format

  # Event-driven: Publish events on image operations
  after_create :publish_image_uploaded_event
  after_create :schedule_thumbnail_generation

  # Position handling for ordering images
  acts_as_list scope: :product

  # Scopes for optimized queries
  scope :with_product, -> { includes(:product) }
  scope :by_product, ->(product_id) { where(product_id: product_id) }

  private

  def validate_image_format
    return unless image.attached?

    errors = ImageValidationService.validate_image(image)
    errors.each { |error| self.errors.add(:image, error) }
  end

  def schedule_thumbnail_generation
    ThumbnailGenerationService.generate_thumbnail(self)
  end

  def publish_image_uploaded_event
    Rails.logger.info("Product image uploaded: ID=#{id}, Product=#{product_id}")
    # In a full event system: EventPublisher.publish('product_image_uploaded', self.attributes)
  end
end