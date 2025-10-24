class ProductImage < ApplicationRecord
  belongs_to :product
  has_one_attached :image
  has_one_attached :thumbnail

  validates :image, presence: true
  validates :thumbnail, allow_nil: true
  validate :acceptable_image

  after_create :schedule_thumbnail_generation

  # Position handling for ordering images
  acts_as_list scope: :product

  private

  def acceptable_image
    return unless image.attached?

    unless image.blob.byte_size <= 10.megabytes
      errors.add(:image, "is too big (should be less than 10MB)")
    end

    acceptable_types = ["image/jpeg", "image/png", "image/webp"]
    unless acceptable_types.include?(image.content_type)
      errors.add(:image, "must be a JPEG, PNG, or WEBP")
    end
  end

  def schedule_thumbnail_generation
    GenerateThumbnailJob.perform_later(id)
  end
end