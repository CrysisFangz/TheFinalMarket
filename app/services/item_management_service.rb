class ItemManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'item_management'
  CACHE_TTL = 15.minutes

  def self.create_item(user, category, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create:#{user.id}:#{category.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_management') do
        with_retry do
          item = Item.new(
            user: user,
            category: category,
            status: :draft,
            **attributes
          )

          if item.save
            EventPublisher.publish('item.created', {
              item_id: item.id,
              user_id: user.id,
              category_id: category.id,
              name: item.name,
              price: item.price,
              status: item.status,
              created_at: item.created_at
            })

            item
          else
            false
          end
        end
      end
    end
  end

  def self.update_item(item, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:update:#{item.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_management') do
        with_retry do
          previous_status = item.status

          if item.update(attributes)
            EventPublisher.publish('item.updated', {
              item_id: item.id,
              user_id: item.user_id,
              category_id: item.category_id,
              name: item.name,
              price: item.price,
              status: item.status,
              previous_status: previous_status,
              updated_at: item.updated_at
            })

            # Clear related caches
            clear_item_cache(item.id)

            true
          else
            false
          end
        end
      end
    end
  end

  def self.activate_item(item)
    cache_key = "#{CACHE_KEY_PREFIX}:activate:#{item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_management') do
        with_retry do
          if item.update(status: :active, activated_at: Time.current)
            EventPublisher.publish('item.activated', {
              item_id: item.id,
              user_id: item.user_id,
              category_id: item.category_id,
              name: item.name,
              activated_at: item.activated_at
            })

            clear_item_cache(item.id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.deactivate_item(item)
    cache_key = "#{CACHE_KEY_PREFIX}:deactivate:#{item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_management') do
        with_retry do
          if item.update(status: :inactive, deactivated_at: Time.current)
            EventPublisher.publish('item.deactivated', {
              item_id: item.id,
              user_id: item.user_id,
              category_id: item.category_id,
              name: item.name,
              deactivated_at: item.deactivated_at
            })

            clear_item_cache(item.id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.mark_item_sold(item)
    cache_key = "#{CACHE_KEY_PREFIX}:sold:#{item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('item_management') do
        with_retry do
          if item.update(status: :sold, sold_at: Time.current)
            EventPublisher.publish('item.sold', {
              item_id: item.id,
              user_id: item.user_id,
              category_id: item.category_id,
              name: item.name,
              price: item.price,
              sold_at: item.sold_at
            })

            clear_item_cache(item.id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.get_items_by_user(user_id)
    cache_key = "#{CACHE_KEY_PREFIX}:user_items:#{user_id}"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      with_circuit_breaker('item_management') do
        with_retry do
          Item.where(user_id: user_id).includes(:category, :reviews).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_items_by_category(category_id)
    cache_key = "#{CACHE_KEY_PREFIX}:category_items:#{category_id}"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      with_circuit_breaker('item_management') do
        with_retry do
          Item.where(category_id: category_id).includes(:user, :reviews).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_active_items
    cache_key = "#{CACHE_KEY_PREFIX}:active_items"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('item_management') do
        with_retry do
          Item.active.includes(:user, :category, :reviews).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.search_items(query, filters = {})
    cache_key = "#{CACHE_KEY_PREFIX}:search:#{query}:#{filters.hash}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('item_management') do
        with_retry do
          items = Item.all

          # Apply text search
          if query.present?
            items = items.where('name ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%")
          end

          # Apply filters
          items = items.where(category_id: filters[:category_id]) if filters[:category_id].present?
          items = items.where(user_id: filters[:user_id]) if filters[:user_id].present?
          items = items.where(status: filters[:status]) if filters[:status].present?
          items = items.where(condition: filters[:condition]) if filters[:condition].present?
          items = items.where('price >= ?', filters[:min_price]) if filters[:min_price].present?
          items = items.where('price <= ?', filters[:max_price]) if filters[:max_price].present?

          # Apply sorting
          case filters[:sort_by]
          when 'price_asc'
            items = items.order(price: :asc)
          when 'price_desc'
            items = items.order(price: :desc)
          when 'newest'
            items = items.order(created_at: :desc)
          when 'oldest'
            items = items.order(created_at: :asc)
          else
            items = items.order(created_at: :desc)
          end

          items = items.includes(:user, :category, :reviews).to_a

          EventPublisher.publish('item.search_performed', {
            query: query,
            filters: filters,
            results_count: items.count,
            searched_at: Time.current
          })

          items
        end
      end
    end
  end

  def self.get_item_stats(user_id = nil)
    cache_key = "#{CACHE_KEY_PREFIX}:stats:#{user_id}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      with_circuit_breaker('item_management') do
        with_retry do
          base_query = user_id ? Item.where(user_id: user_id) : Item.all

          stats = {
            total_items: base_query.count,
            active_items: base_query.where(status: :active).count,
            draft_items: base_query.where(status: :draft).count,
            sold_items: base_query.where(status: :sold).count,
            inactive_items: base_query.where(status: :inactive).count,
            average_price: base_query.average(:price) || 0,
            total_value: base_query.sum(:price),
            items_with_images: base_query.where('images_count > 0').count,
            items_with_reviews: base_query.joins(:reviews).distinct.count,
            generated_at: Time.current
          }

          EventPublisher.publish('item.stats_generated', {
            user_id: user_id,
            stats: stats,
            generated_at: Time.current
          })

          stats
        end
      end
    end
  end

  private

  def self.clear_item_cache(item_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:update:#{item_id}",
      "#{CACHE_KEY_PREFIX}:activate:#{item_id}",
      "#{CACHE_KEY_PREFIX}:deactivate:#{item_id}",
      "#{CACHE_KEY_PREFIX}:sold:#{item_id}",
      "item:#{item_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end

  def self.clear_management_cache
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:active_items",
      "#{CACHE_KEY_PREFIX}:stats"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end