# frozen_string_literal: true

class RecommendationEngine
  def initialize(profile)
    @profile = profile
    @user = profile.user
  end

  def get_recommendations(context = {})
    recommendations = []

    # Collaborative filtering
    recommendations += collaborative_filtering_recommendations

    # Content-based filtering
    recommendations += content_based_recommendations

    # Contextual recommendations
    recommendations += contextual_recommendations(context)

    # Trending items
    recommendations += trending_recommendations

    # Deduplicate and score
    recommendations.uniq { |r| r[:product_id] }
                  .sort_by { |r| -r[:score] }
                  .first(20)
  end

  private

  def collaborative_filtering_recommendations
    # Optimized query to avoid N+1
    similar_users = find_similar_users

    return [] if similar_users.empty?

    Product.joins(:orders)
          .where(orders: { user_id: similar_users.map(&:id) })
          .where.not(id: @user.orders.joins(:line_items).select('line_items.product_id'))
          .distinct
          .limit(10)
          .map { |p| { product_id: p.id, score: 70, reason: 'similar_users' } }
  end

  def content_based_recommendations
    top_cats = @profile.top_categories.first(3)

    return [] if top_cats.empty?

    Product.where(category: top_cats)
          .where.not(id: @user.orders.joins(:line_items).select('line_items.product_id'))
          .order('RANDOM()')
          .limit(10)
          .map { |p| { product_id: p.id, score: 60, reason: 'category_match' } }
  end

  def contextual_recommendations(context)
    recommendations = []

    # Weather-based
    if context[:weather] == 'rainy'
      recommendations += Product.where(category: ['Umbrellas', 'Raincoats']).limit(5)
                               .map { |p| { product_id: p.id, score: 80, reason: 'weather' } }
    end

    # Time-based
    if context[:time_of_day] == 'morning'
      recommendations += Product.where(category: ['Coffee', 'Breakfast']).limit(5)
                               .map { |p| { product_id: p.id, score: 75, reason: 'time_of_day' } }
    end

    # Location-based
    if context[:location]
      # Implement location-based logic here
    end

    recommendations
  end

  def trending_recommendations
    Product.order('views_count DESC')
          .limit(5)
          .map { |p| { product_id: p.id, score: 50, reason: 'trending' } }
  end

  def find_similar_users
    my_categories = @profile.purchase_history&.flat_map { |p| p[:categories] }&.uniq || []

    return [] if my_categories.empty?

    User.joins(:orders)
        .where.not(id: @user.id)
        .select('users.*, COUNT(DISTINCT orders.id) as order_count')
        .group('users.id')
        .having('COUNT(DISTINCT orders.id) > 3')
        .limit(10)
  end
end