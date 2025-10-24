class ItemPresenter
  include CircuitBreaker
  include Retryable

  def initialize(item)
    @item = item
  end

  def as_json(options = {})
    cache_key = "item_presenter:#{@item.id}:#{@item.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('item_presenter') do
        with_retry do
          {
            id: @item.id,
            name: @item.name,
            description: @item.description,
            price: @item.price,
            status: @item.status,
            condition: @item.condition,
            created_at: @item.created_at,
            updated_at: @item.updated_at,
            user: user_data,
            category: category_data,
            inventory: inventory_data,
            reviews: reviews_data,
            images: images_data,
            performance: performance_data,
            recommendations: recommendations
          }
        end
      end
    end
  end

  def to_api_response
    as_json.merge(
      metadata: {
        cache_timestamp: Time.current,
        version: '1.0'
      }
    )
  end

  def to_marketplace_response
    as_json.merge(
      marketplace_data: {
        is_available: @item.active? && inventory_data[:available_quantity] > 0,
        can_be_purchased: can_be_purchased?,
        shipping_info: shipping_info,
        return_policy: return_policy,
        seller_rating: user_data[:average_rating]
      }
    )
  end

  private

  def user_data
    Rails.cache.fetch("item_user:#{@item.user_id}", expires_in: 30.minutes) do
      with_circuit_breaker('user_data') do
        with_retry do
          rating = ItemInventoryService.get_average_rating(@item)

          {
            id: @item.user.id,
            username: @item.user.username,
            average_rating: rating,
            total_reviews: @item.reviews.count,
            total_items: @item.user.items.count,
            member_since: @item.user.created_at
          }
        end
      end
    end
  end

  def category_data
    Rails.cache.fetch("item_category:#{@item.category_id}", expires_in: 30.minutes) do
      with_circuit_breaker('category_data') do
        with_retry do
          {
            id: @item.category.id,
            name: @item.category.name,
            description: @item.category.description,
            parent_id: @item.category.parent_id,
            item_count: @item.category.items.count
          }
        end
      end
    end
  end

  def inventory_data
    Rails.cache.fetch("item_inventory:#{@item.id}", expires_in: 10.minutes) do
      with_circuit_breaker('inventory_data') do
        with_retry do
          ItemInventoryService.get_inventory_status(@item)
        end
      end
    end
  end

  def reviews_data
    Rails.cache.fetch("item_reviews:#{@item.id}", expires_in: 15.minutes) do
      with_circuit_breaker('reviews_data') do
        with_retry do
          {
            average_rating: ItemInventoryService.get_average_rating(@item),
            rating_distribution: ItemInventoryService.get_rating_distribution(@item),
            total_reviews: @item.reviews.count,
            recent_reviews: @item.reviews.recent.limit(5).map do |review|
              {
                id: review.id,
                rating: review.rating,
                content: review.content.truncate(100),
                created_at: review.created_at,
                reviewer: review.reviewer.username
              }
            end
          }
        end
      end
    end
  end

  def images_data
    Rails.cache.fetch("item_images:#{@item.id}", expires_in: 20.minutes) do
      with_circuit_breaker('images_data') do
        with_retry do
          analysis = ItemInventoryService.get_image_analysis(@item)

          {
            image_count: analysis[:image_count],
            image_urls: @item.images.map { |img| Rails.application.routes.url_helpers.rails_blob_path(img, only_path: true) },
            total_size: analysis[:total_size_bytes],
            quality_score: analysis[:image_quality_score],
            has_primary_image: analysis[:has_primary_image]
          }
        end
      end
    end
  end

  def performance_data
    Rails.cache.fetch("item_performance:#{@item.id}", expires_in: 15.minutes) do
      with_circuit_breaker('performance_data') do
        with_retry do
          sales_performance = ItemInventoryService.get_sales_performance(@item)

          {
            total_sold: sales_performance[:total_sold],
            total_revenue: sales_performance[:total_revenue],
            sales_velocity: sales_performance[:sales_velocity],
            conversion_rate: sales_performance[:conversion_rate],
            trending: calculate_trending_status(sales_performance),
            performance_score: calculate_performance_score(sales_performance)
          }
        end
      end
    end
  end

  def recommendations
    Rails.cache.fetch("item_recommendations:#{@item.id}", expires_in: 10.minutes) do
      with_circuit_breaker('recommendations') do
        with_retry do
          recommendations = []

          # Inventory recommendations
          inventory = inventory_data
          if inventory[:is_low_stock]
            recommendations << {
              type: 'inventory',
              priority: 'high',
              message: 'Low stock - consider restocking',
              action: 'reorder'
            }
          end

          if inventory[:needs_reorder]
            recommendations << {
              type: 'inventory',
              priority: 'medium',
              message: 'Below reorder point',
              action: 'reorder'
            }
          end

          # Performance recommendations
          performance = performance_data
          if performance[:conversion_rate] < 1
            recommendations << {
              type: 'marketing',
              priority: 'medium',
              message: 'Low conversion rate - consider price adjustment or promotion',
              action: 'optimize_pricing'
            }
          end

          # Image recommendations
          images = images_data
          if images[:quality_score] < 60
            recommendations << {
              type: 'content',
              priority: 'low',
              message: 'Image quality could be improved',
              action: 'improve_images'
            }
          end

          if images[:image_count] < 3
            recommendations << {
              type: 'content',
              priority: 'low',
              message: 'Consider adding more product images',
              action: 'add_images'
            }
          end

          recommendations
        end
      end
    end
  end

  def shipping_info
    {
      weight: @item.weight,
      dimensions: @item.dimensions,
      shipping_category: @item.shipping_category,
      handling_time: @item.handling_time || 1,
      shipping_restrictions: @item.shipping_restrictions
    }
  end

  def return_policy
    {
      return_window_days: @item.return_window_days || 30,
      return_shipping_paid_by: @item.return_shipping_paid_by || 'buyer',
      return_condition: @item.return_condition || 'new_with_tags',
      exchange_allowed: @item.exchange_allowed || true
    }
  end

  def can_be_purchased?
    @item.active? && inventory_data[:available_quantity] > 0 && !@item.sold?
  end

  def calculate_trending_status(sales_performance)
    velocity = sales_performance[:sales_velocity]

    if velocity > 5
      'trending_up'
    elsif velocity > 1
      'steady'
    else
      'trending_down'
    end
  end

  def calculate_performance_score(sales_performance)
    score = 50 # Base score

    # Sales volume contribution
    score += [sales_performance[:total_sold] * 2, 30].min

    # Revenue contribution
    score += [sales_performance[:total_revenue] / 100, 20].min

    # Conversion rate contribution
    score += [sales_performance[:conversion_rate] * 10, 20].min

    # Inventory turnover (simplified)
    inventory = inventory_data
    if inventory[:stock_quantity] > 0
      turnover_rate = sales_performance[:total_sold].to_f / inventory[:stock_quantity]
      score += [turnover_rate * 20, 20].min
    end

    [score, 100].min
  end
end