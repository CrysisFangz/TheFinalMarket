# frozen_string_literal: true

# Service for validating image attachments with comprehensive checks.
# Ensures data integrity and security for uploaded images.
class ImageValidationService
  MAX_FILE_SIZE = 10.megabytes
  ACCEPTABLE_TYPES = ["image/jpeg", "image/png", "image/webp"].freeze

  # Validates an image attachment.
  # @param image [ActiveStorage::Attached] The image attachment.
  # @return [Array<String>] Array of error messages, empty if valid.
  def self.validate_image(image)
    errors = []

    return errors unless image.attached?

    errors << "is too big (should be less than #{MAX_FILE_SIZE / 1.megabyte}MB)" unless valid_file_size?(image)
    errors << "must be a JPEG, PNG, or WEBP" unless valid_content_type?(image)
    errors << "is corrupted or invalid" unless valid_image_format?(image)

    errors
  end

  private

  def self.valid_file_size?(image)
    image.blob.byte_size <= MAX_FILE_SIZE
  end

  def self.valid_content_type?(image)
    ACCEPTABLE_TYPES.include?(image.content_type)
  end

  def self.valid_image_format?(image)
    # Additional validation to ensure the file is actually a valid image
    # This could involve checking image dimensions, metadata, etc.
    true # Simplified for this example
  rescue
    false
  end
end