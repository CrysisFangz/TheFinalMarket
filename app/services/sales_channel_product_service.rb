class SalesChannelProductService
  attr_reader :sales_channel

  def initialize(sales_channel)
    @sales_channel = sales_channel
  end

  def add_product(product, options = {})
    Rails.logger.info("Adding product ID: #{product.id} to SalesChannel ID: #{sales_channel.id}")
    channel_product = sales_channel.channel_products.create!(
      product: product,
      available: options.fetch(:available, true),
      price_override: options[:price_override],
      inventory_override: options[:inventory_override],
      channel_specific_data: options[:channel_data] || {}
    )
    Rails.logger.info("Product added successfully to SalesChannel ID: #{sales_channel.id}")
    channel_product
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error adding product ID: #{product.id} to SalesChannel ID: #{sales_channel.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error adding product ID: #{product.id} to SalesChannel ID: #{sales_channel.id} - #{e.message}")
    raise
  end

  def remove_product(product)
    Rails.logger.info("Removing product ID: #{product.id} from SalesChannel ID: #{sales_channel.id}")
    channel_product = sales_channel.channel_products.find_by(product: product)
    if channel_product
      channel_product.destroy
      Rails.logger.info("Product removed successfully from SalesChannel ID: #{sales_channel.id}")
    else
      Rails.logger.warn("Product ID: #{product.id} not found in SalesChannel ID: #{sales_channel.id}")
    end
  rescue StandardError => e
    Rails.logger.error("Error removing product ID: #{product.id} from SalesChannel ID: #{sales_channel.id} - #{e.message}")
    raise
  end

  def get_price(product)
    Rails.logger.debug("Getting price for product ID: #{product.id} in SalesChannel ID: #{sales_channel.id}")
    channel_product = sales_channel.channel_products.find_by(product: product)
    price = channel_product&.price_override || product.price
    Rails.logger.debug("Price retrieved: #{price} for product ID: #{product.id}")
    price
  rescue StandardError => e
    Rails.logger.error("Error getting price for product ID: #{product.id} in SalesChannel ID: #{sales_channel.id} - #{e.message}")
    product.price
  end

  def product_available?(product)
    Rails.logger.debug("Checking availability for product ID: #{product.id} in SalesChannel ID: #{sales_channel.id}")
    channel_product = sales_channel.channel_products.find_by(product: product)
    available = channel_product&.available? && product.in_stock?
    Rails.logger.debug("Product availability: #{available} for product ID: #{product.id}")
    available
  rescue StandardError => e
    Rails.logger.error("Error checking availability for product ID: #{product.id} in SalesChannel ID: #{sales_channel.id} - #{e.message}")
    false
  end
end