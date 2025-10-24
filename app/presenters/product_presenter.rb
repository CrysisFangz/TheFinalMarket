class ProductPresenter
  attr_reader :product

  def initialize(product)
    @product = product
  end

  def as_json(options = {})
    {
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      sale_price: product.sale_price,
      currency: product.currency,
      status: product.status,
      availability: product.availability,
      condition: product.condition,
      created_at: product.created_at.iso8601,
      updated_at: product.updated_at.iso8601,
      categories: product.categories.pluck(:name),
      tags: product.tags.pluck(:name),
      variants: product.variants.map { |v| { sku: v.sku, price: v.price, stock: v.stock_quantity } },
      min_price: product.min_price,
      max_price: product.max_price,
      total_stock: product.total_stock
    }.merge(options)
  end

  def for_index
    {
      id: product.id,
      name: product.name,
      price: product.price,
      currency: product.currency,
      status: product.status,
      categories: product.categories.pluck(:name),
      tags: product.tags.pluck(:name)
    }
  end

  def for_show
    as_json.merge(
      specifications: product.specifications,
      ai_insights: product.ai_insights,
      reviews: product.reviews.limit(5).map { |r| { rating: r.rating, comment: r.comment } }
    )
  end

  def for_api
    as_json(except: [:ai_insights])
  end
end