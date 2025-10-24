class RecommendationService
  def generate_recommendations(product, user_context, count = 10)
    # Placeholder for recommendation logic
    # In real implementation, use collaborative filtering, etc.
    Product.where(category: product.categories.first).limit(count)
  end
end