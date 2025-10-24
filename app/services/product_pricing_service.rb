# frozen_string_literal: true

class ProductPricingService
  def initialize(product)
    @product = product
  end

  def min_price
    Rails.cache.fetch("product:#{@product.id}:min_price", expires_in: 30.minutes) do
      @product.variants.minimum(:price) || @product.price
    end
  end

  def max_price
    Rails.cache.fetch("product:#{@product.id}:max_price", expires_in: 30.minutes) do
      @product.variants.maximum(:price) || @product.price
    end
  end
end