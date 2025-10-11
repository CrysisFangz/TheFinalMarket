# app/services/barcode_scanner_service.rb
class BarcodeScannerService
  def initialize
    @api_key = Rails.application.credentials.dig(:barcode_lookup, :api_key)
  end

  # Lookup product by barcode
  def lookup_product(barcode)
    # First check local database
    product = Product.find_by(barcode: barcode)
    return format_product_response(product) if product

    # If not found locally, check external API
    external_product = fetch_from_external_api(barcode)
    
    if external_product
      # Optionally create a new product suggestion
      create_product_suggestion(external_product)
      external_product
    else
      { error: 'Product not found', barcode: barcode }
    end
  end

  # Compare prices across stores
  def compare_prices(barcode)
    product = Product.find_by(barcode: barcode)
    return { error: 'Product not found' } unless product

    # Get all listings for this product
    listings = product.listings.includes(:store, :user).active

    {
      product: format_product_response(product),
      listings: listings.map do |listing|
        {
          id: listing.id,
          price: listing.price,
          condition: listing.condition,
          store_name: listing.store&.name || listing.user&.name,
          distance: listing.distance_from(current_location) if current_location,
          in_stock: listing.in_stock?,
          url: Rails.application.routes.url_helpers.listing_url(listing)
        }
      end.sort_by { |l| l[:price] }
    }
  end

  # Scan history for user
  def save_scan_history(user, barcode, product_data)
    user.barcode_scans.create!(
      barcode: barcode,
      product_name: product_data[:name],
      scanned_at: Time.current,
      metadata: product_data
    )
  end

  private

  def format_product_response(product)
    {
      id: product.id,
      name: product.name,
      description: product.description,
      barcode: product.barcode,
      image_url: product.primary_image_url,
      category: product.category&.name,
      average_price: product.average_price,
      url: Rails.application.routes.url_helpers.product_url(product)
    }
  end

  def fetch_from_external_api(barcode)
    return nil unless @api_key

    begin
      response = HTTP.get("https://api.barcodelookup.com/v3/products", params: {
        barcode: barcode,
        key: @api_key
      })

      if response.status.success?
        data = JSON.parse(response.body)
        parse_external_product(data['products']&.first)
      else
        nil
      end
    rescue => e
      Rails.logger.error("Barcode lookup failed: #{e.message}")
      nil
    end
  end

  def parse_external_product(data)
    return nil unless data

    {
      name: data['title'],
      description: data['description'],
      barcode: data['barcode_number'],
      brand: data['brand'],
      category: data['category'],
      image_url: data['images']&.first,
      external_data: data
    }
  end

  def create_product_suggestion(product_data)
    ProductSuggestion.create!(
      name: product_data[:name],
      barcode: product_data[:barcode],
      external_data: product_data,
      status: 'pending'
    )
  end

  def current_location
    # This would be set from the request context
    @current_location
  end
end

