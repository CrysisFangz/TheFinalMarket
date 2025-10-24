class ItemInventoryService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'item_inventory'
  CACHE_TTL = 10.minutes

  def self.get_average_rating(item)
    cache_key = "#{CACHE_KEY_PREFIX}:rating:#{item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_inventory') do
        with_retry do
          rating = item.reviews.average(:rating) || 0

          EventPublisher.publish('item.rating_calculated', {
            item_id: item.id,
            user_id: item.user_id,
            category_id: item.category_id,
            average_rating: rating,
            review_count: item.reviews.count,
            calculated_at: Time.current
          })

          rating
        end
      end
    end
  end

  def self.get_rating_distribution(item)
    cache_key = "#{CACHE_KEY_PREFIX}:rating_distribution:#{item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_inventory') do
        with_retry do
          distribution = item.reviews.group(:rating).count

          EventPublisher.publish('item.rating_distribution_calculated', {
            item_id: item.id,
            user_id: item.user_id,
            category_id: item.category_id,
            distribution: distribution,
            calculated_at: Time.current
          })

          distribution
        end
      end
    end
  end

  def self.get_inventory_status(item)
    cache_key = "#{CACHE_KEY_PREFIX}:inventory_status:#{item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_inventory') do
        with_retry do
          status = {
            stock_quantity: item.stock_quantity || 0,
            reserved_quantity: item.reserved_quantity || 0,
            available_quantity: (item.stock_quantity || 0) - (item.reserved_quantity || 0),
            reorder_point: item.reorder_point || 0,
            reorder_quantity: item.reorder_quantity || 0,
            low_stock_threshold: item.low_stock_threshold || 5,
            is_low_stock: (item.stock_quantity || 0) <= (item.low_stock_threshold || 5),
            is_out_of_stock: (item.stock_quantity || 0) <= 0,
            needs_reorder: (item.stock_quantity || 0) <= (item.reorder_point || 0)
          }

          EventPublisher.publish('item.inventory_status_calculated', {
            item_id: item.id,
            user_id: item.user_id,
            stock_quantity: status[:stock_quantity],
            available_quantity: status[:available_quantity],
            is_low_stock: status[:is_low_stock],
            is_out_of_stock: status[:is_out_of_stock],
            needs_reorder: status[:needs_reorder],
            calculated_at: Time.current
          })

          status
        end
      end
    end
  end

  def self.update_stock_quantity(item, quantity_change, reason = 'manual_update')
    cache_key = "#{CACHE_KEY_PREFIX}:stock_update:#{item.id}:#{quantity_change}:#{reason}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_inventory') do
        with_retry do
          previous_quantity = item.stock_quantity || 0
          new_quantity = previous_quantity + quantity_change

          if item.update(stock_quantity: new_quantity, last_stock_update: Time.current)
            EventPublisher.publish('item.stock_updated', {
              item_id: item.id,
              user_id: item.user_id,
              previous_quantity: previous_quantity,
              new_quantity: new_quantity,
              quantity_change: quantity_change,
              reason: reason,
              updated_at: item.last_stock_update
            })

            clear_inventory_cache(item.id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.reserve_stock(item, quantity, reservation_id = nil)
    cache_key = "#{CACHE_KEY_PREFIX}:reserve:#{item.id}:#{quantity}:#{reservation_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_inventory') do
        with_retry do
          available_quantity = (item.stock_quantity || 0) - (item.reserved_quantity || 0)

          if available_quantity >= quantity
            new_reserved = (item.reserved_quantity || 0) + quantity

            if item.update(reserved_quantity: new_reserved)
              EventPublisher.publish('item.stock_reserved', {
                item_id: item.id,
                user_id: item.user_id,
                reserved_quantity: quantity,
                total_reserved: new_reserved,
                reservation_id: reservation_id,
                reserved_at: Time.current
              })

              clear_inventory_cache(item.id)
              true
            else
              false
            end
          else
            EventPublisher.publish('item.stock_reservation_failed', {
              item_id: item.id,
              user_id: item.user_id,
              requested_quantity: quantity,
              available_quantity: available_quantity,
              reason: 'insufficient_stock',
              failed_at: Time.current
            })

            false
          end
        end
      end
    end
  end

  def self.release_stock(item, quantity, reservation_id = nil)
    cache_key = "#{CACHE_KEY_PREFIX}:release:#{item.id}:#{quantity}:#{reservation_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_inventory') do
        with_retry do
          current_reserved = item.reserved_quantity || 0

          if current_reserved >= quantity
            new_reserved = current_reserved - quantity

            if item.update(reserved_quantity: new_reserved)
              EventPublisher.publish('item.stock_released', {
                item_id: item.id,
                user_id: item.user_id,
                released_quantity: quantity,
                remaining_reserved: new_reserved,
                reservation_id: reservation_id,
                released_at: Time.current
              })

              clear_inventory_cache(item.id)
              true
            else
              false
            end
          else
            false
          end
        end
      end
    end
  end

  def self.get_image_analysis(item)
    cache_key = "#{CACHE_KEY_PREFIX}:image_analysis:#{item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_inventory') do
        with_retry do
          analysis = {
            image_count: item.images.count,
            image_sizes: item.images.map { |img| { filename: img.filename, size: img.byte_size } },
            has_primary_image: item.images.any?,
            total_size_bytes: item.images.sum(&:byte_size),
            average_image_size: item.images.any? ? item.images.sum(&:byte_size) / item.images.count : 0,
            image_quality_score: calculate_image_quality_score(item.images)
          }

          EventPublisher.publish('item.image_analysis_performed', {
            item_id: item.id,
            user_id: item.user_id,
            image_count: analysis[:image_count],
            total_size_bytes: analysis[:total_size_bytes],
            quality_score: analysis[:image_quality_score],
            analyzed_at: Time.current
          })

          analysis
        end
      end
    end
  end

  def self.get_sales_performance(item, period = 30)
    cache_key = "#{CACHE_KEY_PREFIX}:sales_performance:#{item.id}:#{period}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_inventory') do
        with_retry do
          start_date = period.days.ago

          order_items = item.order_items.joins(:order).where('orders.created_at >= ?', start_date)

          performance = {
            total_sold: order_items.sum(:quantity),
            total_revenue: order_items.sum('quantity * price'),
            order_count: order_items.distinct.count(:order_id),
            average_order_quantity: order_items.any? ? order_items.sum(:quantity) / order_items.distinct.count(:order_id).to_f : 0,
            sales_velocity: order_items.sum(:quantity) / period.to_f,
            peak_sales_date: order_items.group_by_day(:created_at).count.max_by { |_, count| count }&.first,
            conversion_rate: calculate_conversion_rate(item, start_date)
          }

          EventPublisher.publish('item.sales_performance_calculated', {
            item_id: item.id,
            user_id: item.user_id,
            period: period,
            total_sold: performance[:total_sold],
            total_revenue: performance[:total_revenue],
            calculated_at: Time.current
          })

          performance
        end
      end
    end
  end

  private

  def self.calculate_image_quality_score(images)
    return 0 if images.empty?

    score = 0
    score += 20 if images.count >= 3 # Multiple images
    score += 20 if images.any? { |img| img.byte_size > 500.kilobytes } # High quality images
    score += 20 if images.all? { |img| img.content_type.in?(['image/jpeg', 'image/png']) } # Proper format
    score += 20 if images.sum(&:byte_size) > 2.megabytes # Sufficient total size
    score += 20 if images.all? { |img| img.filename.to_s.length > 10 } # Descriptive filenames

    score
  end

  def self.calculate_conversion_rate(item, start_date)
    # This would require view data - simplified for now
    views = item.product_views.where('created_at >= ?', start_date).count
    purchases = item.order_items.joins(:order).where('orders.created_at >= ?', start_date).distinct.count(:order_id)

    views > 0 ? (purchases.to_f / views) * 100 : 0
  end

  def self.clear_inventory_cache(item_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:rating:#{item_id}",
      "#{CACHE_KEY_PREFIX}:rating_distribution:#{item_id}",
      "#{CACHE_KEY_PREFIX}:inventory_status:#{item_id}",
      "#{CACHE_KEY_PREFIX}:stock_update:#{item_id}",
      "#{CACHE_KEY_PREFIX}:reserve:#{item_id}",
      "#{CACHE_KEY_PREFIX}:release:#{item_id}",
      "#{CACHE_KEY_PREFIX}:image_analysis:#{item_id}",
      "#{CACHE_KEY_PREFIX}:sales_performance:#{item_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end