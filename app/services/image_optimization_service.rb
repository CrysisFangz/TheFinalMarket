# frozen_string_literal: true

class ImageOptimizationService
  SIZES = {
    thumbnail: { width: 150, height: 150 },
    small: { width: 300, height: 300 },
    medium: { width: 600, height: 600 },
    large: { width: 1200, height: 1200 },
    xlarge: { width: 2400, height: 2400 }
  }.freeze

  FORMATS = [:webp, :avif, :jpeg, :png].freeze

  def initialize(image_path_or_blob)
    @source = image_path_or_blob
  end

  # Generate all size variants for an image
  def generate_variants
    variants = {}
    
    SIZES.each do |size_name, dimensions|
      variants[size_name] = {}
      
      FORMATS.each do |format|
        variants[size_name][format] = generate_variant(size_name, format)
      end
    end
    
    variants
  end

  # Generate a specific variant
  def generate_variant(size, format = :webp)
    dimensions = SIZES[size]
    return nil unless dimensions

    processed = ImageProcessing::Vips
      .source(@source)
      .resize_to_limit(dimensions[:width], dimensions[:height])
      .convert(format.to_s)
      .saver(quality: quality_for_format(format), strip: true)
      .call

    processed
  end

  # Generate blur placeholder (tiny base64 encoded image)
  def generate_blur_placeholder
    tiny = ImageProcessing::Vips
      .source(@source)
      .resize_to_limit(20, 20)
      .convert('jpeg')
      .saver(quality: 50)
      .call

    # Convert to base64 data URL
    data = File.binread(tiny.path)
    base64 = Base64.strict_encode64(data)
    "data:image/jpeg;base64,#{base64}"
  end

  # Optimize existing image
  def optimize
    ImageProcessing::Vips
      .source(@source)
      .saver(quality: 85, strip: true, interlace: true)
      .call
  end

  # Convert to WebP
  def to_webp
    ImageProcessing::Vips
      .source(@source)
      .convert('webp')
      .saver(quality: 85, strip: true)
      .call
  end

  # Convert to AVIF (next-gen format)
  def to_avif
    ImageProcessing::Vips
      .source(@source)
      .convert('avif')
      .saver(quality: 80, strip: true)
      .call
  end

  # Get image dimensions
  def dimensions
    image = Vips::Image.new_from_file(@source.is_a?(String) ? @source : @source.path)
    { width: image.width, height: image.height }
  end

  # Calculate optimal quality based on format
  def quality_for_format(format)
    case format
    when :webp
      85
    when :avif
      80
    when :jpeg
      85
    when :png
      100
    else
      85
    end
  end

  # Lazy loading attributes for img tag
  def self.lazy_loading_attrs(src, alt: '', sizes: '100vw')
    {
      src: src,
      alt: alt,
      loading: 'lazy',
      decoding: 'async',
      sizes: sizes
    }
  end

  # Generate srcset for responsive images
  def self.generate_srcset(image_urls)
    image_urls.map { |url, width| "#{url} #{width}w" }.join(', ')
  end

  # Picture element with WebP and fallback
  def self.picture_tag(image, alt: '', css_class: '')
    <<~HTML
      <picture>
        <source type="image/webp" srcset="#{image.webp_url}">
        <source type="image/jpeg" srcset="#{image.url}">
        <img src="#{image.url}" 
             alt="#{alt}" 
             class="#{css_class}"
             loading="lazy"
             decoding="async">
      </picture>
    HTML
  end
end

