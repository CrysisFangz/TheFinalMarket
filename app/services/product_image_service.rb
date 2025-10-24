# frozen_string_literal: true

class ProductImageService
  def self.generate_thumbnail(product_image)
    return unless product_image.image.attached?

    thumbnail_path = product_image.image.blob.service.send(:path_for, product_image.image.key)
    processed_thumbnail = MiniMagick::Image.open(thumbnail_path)
    processed_thumbnail.resize "300x300>"

    temp_file = Tempfile.new(['thumbnail', '.jpg'])
    processed_thumbnail.write(temp_file.path)

    product_image.thumbnail.attach(
      io: File.open(temp_file.path),
      filename: "thumbnail_#{product_image.image.filename}",
      content_type: 'image/jpeg'
    )
  ensure
    temp_file&.close
    temp_file&.unlink
  end
end