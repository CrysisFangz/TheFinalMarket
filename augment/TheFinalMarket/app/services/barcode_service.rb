# frozen_string_literal: true

# Service for handling barcode scanning and product lookup
class BarcodeService
  class BarcodeNotFoundError < StandardError; end
  class InvalidBarcodeError < StandardError; end

  BARCODE_TYPES = %w[
    EAN-13 EAN-8 UPC-A UPC-E
    Code-128 Code-39 Code-93
    ITF QR DataMatrix PDF417
  ].freeze

  def initialize(barcode_data, barcode_type: 'EAN-13')
    @barcode_data = barcode_data
    @barcode_type = barcode_type
    validate_barcode!
  end

  # Find product by barcode
  def find_product
    product = Product.find_by(barcode: @barcode_data) ||
              Product.find_by(sku: @barcode_data) ||
              Product.find_by(upc: @barcode_data)

    return product if product

    # Try external product databases
    fetch_from_external_database
  end

  # Compare prices across stores
  def compare_prices
    product = find_product
    raise BarcodeNotFoundError, "Product not found for barcode: #{@barcode_data}" unless product

    {
      product: product,
      current_price: product.price,
      competitor_prices: fetch_competitor_prices(product),
      price_history: product.price_histories.order(created_at: :desc).limit(30),
      best_deal: find_best_deal(product),
      savings: calculate_savings(product)
    }
  end

  # Get product information
  def product_info
    product = find_product
    raise BarcodeNotFoundError, "Product not found" unless product

    {
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      barcode: @barcode_data,
      barcode_type: @barcode_type,
      images: product.images.map(&:url),
      stock: product.stock_quantity,
      category: product.category&.name,
      brand: product.brand,
      rating: product.average_rating,
      reviews_count: product.reviews.count
    }
  end

  # Scan and add to cart
  def scan_to_cart(user, quantity: 1)
    product = find_product
    raise BarcodeNotFoundError, "Product not found" unless product

    cart = user.cart || user.create_cart
    cart_item = cart.cart_items.find_or_initialize_by(product: product)
    cart_item.quantity = (cart_item.quantity || 0) + quantity
    cart_item.save!

    {
      success: true,
      product: product,
      cart_item: cart_item,
      cart_total: cart.total_price,
      items_count: cart.cart_items.sum(:quantity)
    }
  end

  # Get barcode image (for display/verification)
  def generate_barcode_image(format: 'png')
    require 'barby'
    require 'barby/barcode/ean_13'
    require 'barby/outputter/png_outputter'

    barcode = case @barcode_type
              when 'EAN-13'
                Barby::EAN13.new(@barcode_data)
              when 'Code-128'
                Barby::Code128B.new(@barcode_data)
              else
                raise InvalidBarcodeError, "Unsupported barcode type: #{@barcode_type}"
              end

    outputter = Barby::PngOutputter.new(barcode)
    outputter.to_png
  end

  private

  def validate_barcode!
    raise InvalidBarcodeError, "Barcode data cannot be blank" if @barcode_data.blank?
    raise InvalidBarcodeError, "Invalid barcode type" unless BARCODE_TYPES.include?(@barcode_type)

    # Validate EAN-13 checksum
    if @barcode_type == 'EAN-13' && @barcode_data.length == 13
      validate_ean13_checksum!
    end
  end

  def validate_ean13_checksum!
    digits = @barcode_data.chars.map(&:to_i)
    check_digit = digits.pop
    
    sum = digits.each_with_index.sum do |digit, index|
      index.even? ? digit : digit * 3
    end
    
    calculated_check = (10 - (sum % 10)) % 10
    
    unless calculated_check == check_digit
      raise InvalidBarcodeError, "Invalid EAN-13 checksum"
    end
  end

  def fetch_from_external_database
    # Integration with external product databases
    # Examples: UPC Database, Open Food Facts, etc.
    
    # For now, return nil - implement actual API calls as needed
    nil
  end

  def fetch_competitor_prices(product)
    # Fetch prices from competitor stores
    # This would integrate with price comparison APIs
    
    [
      { store: 'Store A', price: product.price * 1.1, distance: 2.5 },
      { store: 'Store B', price: product.price * 0.95, distance: 5.0 },
      { store: 'Store C', price: product.price * 1.05, distance: 1.2 }
    ]
  end

  def find_best_deal(product)
    prices = fetch_competitor_prices(product)
    best = prices.min_by { |p| p[:price] }
    
    {
      store: best[:store],
      price: best[:price],
      savings: product.price - best[:price],
      distance: best[:distance]
    }
  end

  def calculate_savings(product)
    competitor_prices = fetch_competitor_prices(product)
    avg_competitor_price = competitor_prices.sum { |p| p[:price] } / competitor_prices.size
    
    {
      vs_average: avg_competitor_price - product.price,
      vs_highest: competitor_prices.max_by { |p| p[:price] }[:price] - product.price,
      percentage: ((avg_competitor_price - product.price) / avg_competitor_price * 100).round(2)
    }
  end
end

