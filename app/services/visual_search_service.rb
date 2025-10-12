# app/services/visual_search_service.rb
class VisualSearchService
  def initialize
    @vision_api_key = Rails.application.credentials.dig(:google_vision, :api_key)
    @image_search_api_key = Rails.application.credentials.dig(:image_search, :api_key)
  end

  # Analyze image and find similar products
  def search_by_image(image_data)
    # First, analyze the image to extract features
    image_analysis = analyze_image(image_data)
    
    return { error: 'Image analysis failed' } unless image_analysis[:success]

    # Search for similar products based on analysis
    search_results = find_similar_products(image_analysis)

    {
      success: true,
      analysis: image_analysis,
      products: search_results,
      suggestions: generate_search_suggestions(image_analysis)
    }
  end

  # Analyze image using Google Vision API
  def analyze_image(image_data)
    return { success: false, error: 'No API key configured' } unless @vision_api_key

    begin
      # Prepare image for API
      image_content = prepare_image(image_data)

      response = HTTP.post(
        "https://vision.googleapis.com/v1/images:annotate?key=#{@vision_api_key}",
        json: {
          requests: [{
            image: { content: image_content },
            features: [
              { type: 'LABEL_DETECTION', maxResults: 10 },
              { type: 'OBJECT_LOCALIZATION', maxResults: 10 },
              { type: 'IMAGE_PROPERTIES' },
              { type: 'WEB_DETECTION', maxResults: 10 },
              { type: 'PRODUCT_SEARCH', maxResults: 10 }
            ]
          }]
        }
      )

      if response.status.success?
        parse_vision_response(JSON.parse(response.body))
      else
        { success: false, error: 'Vision API request failed' }
      end
    rescue => e
      Rails.logger.error("Image analysis failed: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # Find similar products in database
  def find_similar_products(analysis)
    return [] unless analysis[:success]

    products = []
    labels = analysis[:labels] || []
    colors = analysis[:dominant_colors] || []

    # Search by labels/tags
    if labels.any?
      label_search = Product.joins(:tags)
                            .where('tags.name IN (?)', labels.map(&:downcase))
                            .distinct
                            .limit(20)
      products.concat(label_search)
    end

    # Search by category
    if analysis[:category]
      category = Category.find_by('LOWER(name) = ?', analysis[:category].downcase)
      if category
        category_products = category.products.active.limit(10)
        products.concat(category_products)
      end
    end

    # Search by color
    if colors.any?
      color_products = Product.where('primary_color IN (?)', colors).limit(10)
      products.concat(color_products)
    end

    # Search by text detected in image
    if analysis[:text].present?
      text_products = Product.search(analysis[:text]).limit(10)
      products.concat(text_products)
    end

    # Remove duplicates and score by relevance
    products.uniq.map do |product|
      {
        id: product.id,
        name: product.name,
        description: product.description,
        price: product.price,
        image_url: product.primary_image_url,
        category: product.category&.name,
        relevance_score: calculate_relevance(product, analysis),
        url: Rails.application.routes.url_helpers.product_url(product)
      }
    end.sort_by { |p| -p[:relevance_score] }.take(20)
  end

  # Extract product information from image
  def extract_product_info(image_data)
    analysis = analyze_image(image_data)
    
    return { error: 'Analysis failed' } unless analysis[:success]

    {
      suggested_name: generate_product_name(analysis),
      suggested_category: analysis[:category],
      suggested_tags: analysis[:labels],
      dominant_colors: analysis[:dominant_colors],
      detected_text: analysis[:text],
      suggested_description: generate_description(analysis)
    }
  end

  private

  def prepare_image(image_data)
    # If image_data is a file path
    if image_data.is_a?(String) && File.exist?(image_data)
      Base64.strict_encode64(File.read(image_data))
    # If image_data is already base64
    elsif image_data.is_a?(String) && image_data.include?('base64')
      image_data.split(',').last
    # If image_data is binary
    else
      Base64.strict_encode64(image_data)
    end
  end

  def parse_vision_response(response)
    result = response['responses']&.first
    return { success: false, error: 'No response data' } unless result

    {
      success: true,
      labels: extract_labels(result['labelAnnotations']),
      objects: extract_objects(result['localizedObjectAnnotations']),
      dominant_colors: extract_colors(result['imagePropertiesAnnotation']),
      web_entities: extract_web_entities(result['webDetection']),
      text: extract_text(result['textAnnotations']),
      category: determine_category(result)
    }
  end

  def extract_labels(annotations)
    return [] unless annotations
    annotations.map { |a| a['description'] }.take(10)
  end

  def extract_objects(annotations)
    return [] unless annotations
    annotations.map { |a| { name: a['name'], confidence: a['score'] } }
  end

  def extract_colors(properties)
    return [] unless properties && properties['dominantColors']
    
    properties['dominantColors']['colors'].take(3).map do |color|
      rgb = color['color']
      rgb_to_color_name(rgb['red'], rgb['green'], rgb['blue'])
    end.compact.uniq
  end

  def extract_web_entities(web_detection)
    return [] unless web_detection && web_detection['webEntities']
    web_detection['webEntities'].map { |e| e['description'] }.compact.take(5)
  end

  def extract_text(annotations)
    return nil unless annotations && annotations.any?
    annotations.first['description']
  end

  def determine_category(result)
    labels = extract_labels(result['labelAnnotations'])
    
    # Map common labels to categories
    category_mapping = {
      'clothing' => 'Fashion',
      'electronics' => 'Electronics',
      'furniture' => 'Home & Garden',
      'book' => 'Books',
      'toy' => 'Toys & Games',
      'food' => 'Food & Beverage',
      'vehicle' => 'Automotive',
      'jewelry' => 'Jewelry & Accessories'
    }

    labels.each do |label|
      category_mapping.each do |key, category|
        return category if label.downcase.include?(key)
      end
    end

    nil
  end

  def calculate_relevance(product, analysis)
    score = 0.0
    
    # Match labels
    product_tags = product.tags.pluck(:name).map(&:downcase)
    matching_labels = (analysis[:labels].map(&:downcase) & product_tags).count
    score += matching_labels * 2.0

    # Match category
    if analysis[:category] && product.category&.name == analysis[:category]
      score += 5.0
    end

    # Match colors
    if analysis[:dominant_colors].include?(product.primary_color)
      score += 1.0
    end

    score
  end

  def generate_product_name(analysis)
    objects = analysis[:objects] || []
    labels = analysis[:labels] || []
    
    if objects.any?
      objects.first[:name].titleize
    elsif labels.any?
      labels.first.titleize
    else
      'Unknown Product'
    end
  end

  def generate_description(analysis)
    parts = []
    
    parts << "Detected objects: #{analysis[:objects].map { |o| o[:name] }.join(', ')}" if analysis[:objects].any?
    parts << "Colors: #{analysis[:dominant_colors].join(', ')}" if analysis[:dominant_colors].any?
    parts << "Labels: #{analysis[:labels].join(', ')}" if analysis[:labels].any?
    
    parts.join('. ')
  end

  def generate_search_suggestions(analysis)
    suggestions = []
    
    # Combine labels for search suggestions
    labels = analysis[:labels] || []
    labels.combination(2).take(5).each do |combo|
      suggestions << combo.join(' ')
    end

    # Add category-based suggestions
    if analysis[:category]
      suggestions << analysis[:category]
    end

    suggestions.uniq.take(5)
  end

  def rgb_to_color_name(r, g, b)
    # Simple color name mapping
    return 'red' if r > 200 && g < 100 && b < 100
    return 'green' if g > 200 && r < 100 && b < 100
    return 'blue' if b > 200 && r < 100 && g < 100
    return 'yellow' if r > 200 && g > 200 && b < 100
    return 'purple' if r > 150 && b > 150 && g < 100
    return 'orange' if r > 200 && g > 100 && g < 200 && b < 100
    return 'black' if r < 50 && g < 50 && b < 50
    return 'white' if r > 200 && g > 200 && b > 200
    return 'gray' if (r - g).abs < 30 && (g - b).abs < 30
    nil
  end
end

