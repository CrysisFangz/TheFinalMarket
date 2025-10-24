# frozen_string_literal: true

class PersonalizationService
  def initialize(profile)
    @profile = profile
    @user = profile.user
  end

  def update_from_behavior(event_type, data = {})
    case event_type.to_sym
    when :product_view
      track_product_interest(data[:product])
    when :search
      track_search_interest(data[:query])
    when :purchase
      track_purchase_behavior(data[:order])
    when :cart_add
      track_cart_behavior(data[:product])
    when :wishlist_add
      track_wishlist_behavior(data[:product])
    end

    # Schedule async updates
    UpdateProfileJob.perform_later(@profile.id)
  rescue StandardError => e
    Rails.logger.error("Error updating personalization profile: #{e.message}")
    # Optionally, retry or handle differently
  end

  private

  def track_product_interest(product)
    interests = @profile.product_interests || {}
    category = product.category

    interests[category] ||= 0
    interests[category] += 1

    @profile.update!(product_interests: interests)
  end

  def track_search_interest(query)
    searches = @profile.search_history || []
    searches << { query: query, timestamp: Time.current }
    searches = searches.last(100)

    @profile.update!(search_history: searches)
  end

  def track_purchase_behavior(order)
    purchases = @profile.purchase_history || []
    purchases << {
      order_id: order.id,
      total: order.total_cents,
      date: order.created_at,
      categories: order.line_items.map { |li| li.product.category }.uniq
    }

    @profile.update!(
      purchase_history: purchases,
      last_purchase_at: order.created_at
    )
  end

  def track_cart_behavior(product)
    cart_items = @profile.cart_history || []
    cart_items << {
      product_id: product.id,
      category: product.category,
      price: product.price_cents,
      timestamp: Time.current
    }

    @profile.update!(cart_history: cart_items.last(100))
  end

  def track_wishlist_behavior(product)
    wishlist_items = @profile.wishlist_history || []
    wishlist_items << {
      product_id: product.id,
      category: product.category,
      timestamp: Time.current
    }

    @profile.update!(wishlist_history: wishlist_items.last(100))
  end
end