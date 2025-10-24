class LineItemManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'line_item_management'
  CACHE_TTL = 10.minutes

  def self.create_line_item(product, cart, quantity = 1, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create:#{product.id}:#{cart.id}:#{quantity}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          # Check if line item already exists
          existing_item = LineItem.find_by(product: product, cart: cart)

          if existing_item
            # Update quantity instead of creating new
            update_line_item(existing_item, quantity: existing_item.quantity + quantity)
          else
            line_item = LineItem.new(
              product: product,
              cart: cart,
              quantity: quantity,
              **attributes
            )

            if line_item.save
              EventPublisher.publish('line_item.created', {
                line_item_id: line_item.id,
                product_id: product.id,
                cart_id: cart.id,
                quantity: quantity,
                total_price: line_item.total_price,
                created_at: line_item.created_at
              })

              clear_cart_cache(cart.id)
              line_item
            else
              false
            end
          end
        end
      end
    end
  end

  def self.update_line_item(line_item, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:update:#{line_item.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          previous_quantity = line_item.quantity
          previous_total = line_item.total_price

          if line_item.update(attributes)
            EventPublisher.publish('line_item.updated', {
              line_item_id: line_item.id,
              product_id: line_item.product_id,
              cart_id: line_item.cart_id,
              quantity: line_item.quantity,
              total_price: line_item.total_price,
              previous_quantity: previous_quantity,
              previous_total: previous_total,
              updated_at: line_item.updated_at
            })

            clear_cart_cache(line_item.cart_id)
            clear_product_cache(line_item.product_id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.delete_line_item(line_item)
    cache_key = "#{CACHE_KEY_PREFIX}:delete:#{line_item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          cart_id = line_item.cart_id
          product_id = line_item.product_id

          line_item.destroy

          EventPublisher.publish('line_item.deleted', {
            line_item_id: line_item.id,
            product_id: product_id,
            cart_id: cart_id,
            quantity: line_item.quantity,
            total_price: line_item.total_price,
            deleted_at: Time.current
          })

          clear_cart_cache(cart_id)
          clear_product_cache(product_id)
          true
        end
      end
    end
  end

  def self.get_line_items_for_cart(cart_id)
    cache_key = "#{CACHE_KEY_PREFIX}:cart_items:#{cart_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          LineItem.where(cart_id: cart_id).includes(:product).order(created_at: :asc).to_a
        end
      end
    end
  end

  def self.get_line_items_for_product(product_id)
    cache_key = "#{CACHE_KEY_PREFIX}:product_items:#{product_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          LineItem.where(product_id: product_id).includes(:cart).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_cart_summary(cart_id)
    cache_key = "#{CACHE_KEY_PREFIX}:cart_summary:#{cart_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          line_items = get_line_items_for_cart(cart_id)

          summary = {
            item_count: line_items.count,
            total_quantity: line_items.sum(:quantity),
            total_price: line_items.sum { |item| item.total_price },
            unique_products: line_items.map(&:product_id).uniq.count,
            average_price: line_items.any? ? line_items.sum { |item| item.total_price } / line_items.count : 0,
            items: line_items.map do |item|
              {
                id: item.id,
                product_id: item.product_id,
                product_name: item.product.name,
                quantity: item.quantity,
                unit_price: item.product.price,
                total_price: item.total_price
              }
            end
          }

          EventPublisher.publish('line_item.cart_summary_generated', {
            cart_id: cart_id,
            item_count: summary[:item_count],
            total_quantity: summary[:total_quantity],
            total_price: summary[:total_price],
            generated_at: Time.current
          })

          summary
        end
      end
    end
  end

  def self.get_product_availability(product_id)
    cache_key = "#{CACHE_KEY_PREFIX}:product_availability:#{product_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          product = Product.find(product_id)

          availability = {
            product_id: product_id,
            stock_quantity: product.stock_quantity,
            reserved_quantity: product.reserved_quantity,
            available_quantity: product.stock_quantity - product.reserved_quantity,
            in_carts: LineItem.where(product_id: product_id).sum(:quantity),
            is_available: product.active? && (product.stock_quantity - product.reserved_quantity) > 0
          }

          EventPublisher.publish('line_item.product_availability_checked', {
            product_id: product_id,
            available_quantity: availability[:available_quantity],
            in_carts: availability[:in_carts],
            is_available: availability[:is_available],
            checked_at: Time.current
          })

          availability
        end
      end
    end
  end

  def self.validate_line_item_quantity(line_item, new_quantity)
    cache_key = "#{CACHE_KEY_PREFIX}:validate_quantity:#{line_item.id}:#{new_quantity}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          availability = get_product_availability(line_item.product_id)

          validation = {
            valid: true,
            warnings: [],
            errors: []
          }

          # Check if quantity is valid
          if new_quantity <= 0
            validation[:valid] = false
            validation[:errors] << 'Quantity must be greater than 0'
          end

          # Check stock availability
          if new_quantity > availability[:available_quantity]
            validation[:valid] = false
            validation[:errors] << 'Insufficient stock available'
            validation[:warnings] << 'Only ' + availability[:available_quantity].to_s + ' items available'
          end

          # Check cart limits
          if new_quantity > 99
            validation[:warnings] << 'Large quantities may affect shipping costs'
          end

          validation
        end
      end
    end
  end

  def self.get_bulk_line_item_operations(cart_id, operations)
    cache_key = "#{CACHE_KEY_PREFIX}:bulk_operations:#{cart_id}:#{operations.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          results = []
          errors = []

          operations.each do |operation|
            begin
              case operation[:action]
              when 'add'
                product = Product.find(operation[:product_id])
                cart = Cart.find(cart_id)
                result = create_line_item(product, cart, operation[:quantity], operation[:attributes] || {})
                results << result if result
              when 'update'
                line_item = LineItem.find(operation[:line_item_id])
                result = update_line_item(line_item, operation[:attributes])
                results << result if result
              when 'remove'
                line_item = LineItem.find(operation[:line_item_id])
                result = delete_line_item(line_item)
                results << result if result
              else
                errors << "Unknown operation: #{operation[:action]}"
              end
            rescue => e
              errors << "Failed to execute #{operation[:action]}: #{e.message}"
            end
          end

          EventPublisher.publish('line_item.bulk_operations_completed', {
            cart_id: cart_id,
            operations_count: operations.count,
            successful_operations: results.count,
            errors_count: errors.count,
            completed_at: Time.current
          })

          clear_cart_cache(cart_id)
          { results: results, errors: errors }
        end
      end
    end
  end

  private

  def self.clear_cart_cache(cart_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:cart_items:#{cart_id}",
      "#{CACHE_KEY_PREFIX}:cart_summary:#{cart_id}",
      "#{CACHE_KEY_PREFIX}:bulk_operations:#{cart_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end

  def self.clear_product_cache(product_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:product_items:#{product_id}",
      "#{CACHE_KEY_PREFIX}:product_availability:#{product_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end</content>
<content lines="1-150">
class LineItemManagementService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'line_item_management'
  CACHE_TTL = 10.minutes

  def self.create_line_item(product, cart, quantity = 1, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:create:#{product.id}:#{cart.id}:#{quantity}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          # Check if line item already exists
          existing_item = LineItem.find_by(product: product, cart: cart)

          if existing_item
            # Update quantity instead of creating new
            update_line_item(existing_item, quantity: existing_item.quantity + quantity)
          else
            line_item = LineItem.new(
              product: product,
              cart: cart,
              quantity: quantity,
              **attributes
            )

            if line_item.save
              EventPublisher.publish('line_item.created', {
                line_item_id: line_item.id,
                product_id: product.id,
                cart_id: cart.id,
                quantity: quantity,
                total_price: line_item.total_price,
                created_at: line_item.created_at
              })

              clear_cart_cache(cart.id)
              line_item
            else
              false
            end
          end
        end
      end
    end
  end

  def self.update_line_item(line_item, attributes = {})
    cache_key = "#{CACHE_KEY_PREFIX}:update:#{line_item.id}:#{attributes.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          previous_quantity = line_item.quantity
          previous_total = line_item.total_price

          if line_item.update(attributes)
            EventPublisher.publish('line_item.updated', {
              line_item_id: line_item.id,
              product_id: line_item.product_id,
              cart_id: line_item.cart_id,
              quantity: line_item.quantity,
              total_price: line_item.total_price,
              previous_quantity: previous_quantity,
              previous_total: previous_total,
              updated_at: line_item.updated_at
            })

            clear_cart_cache(line_item.cart_id)
            clear_product_cache(line_item.product_id)
            true
          else
            false
          end
        end
      end
    end
  end

  def self.delete_line_item(line_item)
    cache_key = "#{CACHE_KEY_PREFIX}:delete:#{line_item.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          cart_id = line_item.cart_id
          product_id = line_item.product_id

          line_item.destroy

          EventPublisher.publish('line_item.deleted', {
            line_item_id: line_item.id,
            product_id: product_id,
            cart_id: cart_id,
            quantity: line_item.quantity,
            total_price: line_item.total_price,
            deleted_at: Time.current
          })

          clear_cart_cache(cart_id)
          clear_product_cache(product_id)
          true
        end
      end
    end
  end

  def self.get_line_items_for_cart(cart_id)
    cache_key = "#{CACHE_KEY_PREFIX}:cart_items:#{cart_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          LineItem.where(cart_id: cart_id).includes(:product).order(created_at: :asc).to_a
        end
      end
    end
  end

  def self.get_line_items_for_product(product_id)
    cache_key = "#{CACHE_KEY_PREFIX}:product_items:#{product_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          LineItem.where(product_id: product_id).includes(:cart).order(created_at: :desc).to_a
        end
      end
    end
  end

  def self.get_cart_summary(cart_id)
    cache_key = "#{CACHE_KEY_PREFIX}:cart_summary:#{cart_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          line_items = get_line_items_for_cart(cart_id)

          summary = {
            item_count: line_items.count,
            total_quantity: line_items.sum(:quantity),
            total_price: line_items.sum { |item| item.total_price },
            unique_products: line_items.map(&:product_id).uniq.count,
            average_price: line_items.any? ? line_items.sum { |item| item.total_price } / line_items.count : 0,
            items: line_items.map do |item|
              {
                id: item.id,
                product_id: item.product_id,
                product_name: item.product.name,
                quantity: item.quantity,
                unit_price: item.product.price,
                total_price: item.total_price
              }
            end
          }

          EventPublisher.publish('line_item.cart_summary_generated', {
            cart_id: cart_id,
            item_count: summary[:item_count],
            total_quantity: summary[:total_quantity],
            total_price: summary[:total_price],
            generated_at: Time.current
          })

          summary
        end
      end
    end
  end

  def self.get_product_availability(product_id)
    cache_key = "#{CACHE_KEY_PREFIX}:product_availability:#{product_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          product = Product.find(product_id)

          availability = {
            product_id: product_id,
            stock_quantity: product.stock_quantity,
            reserved_quantity: product.reserved_quantity,
            available_quantity: product.stock_quantity - product.reserved_quantity,
            in_carts: LineItem.where(product_id: product_id).sum(:quantity),
            is_available: product.active? && (product.stock_quantity - product.reserved_quantity) > 0
          }

          EventPublisher.publish('line_item.product_availability_checked', {
            product_id: product_id,
            available_quantity: availability[:available_quantity],
            in_carts: availability[:in_carts],
            is_available: availability[:is_available],
            checked_at: Time.current
          })

          availability
        end
      end
    end
  end

  def self.validate_line_item_quantity(line_item, new_quantity)
    cache_key = "#{CACHE_KEY_PREFIX}:validate_quantity:#{line_item.id}:#{new_quantity}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          availability = get_product_availability(line_item.product_id)

          validation = {
            valid: true,
            warnings: [],
            errors: []
          }

          # Check if quantity is valid
          if new_quantity <= 0
            validation[:valid] = false
            validation[:errors] << 'Quantity must be greater than 0'
          end

          # Check stock availability
          if new_quantity > availability[:available_quantity]
            validation[:valid] = false
            validation[:errors] << 'Insufficient stock available'
            validation[:warnings] << 'Only ' + availability[:available_quantity].to_s + ' items available'
          end

          # Check cart limits
          if new_quantity > 99
            validation[:warnings] << 'Large quantities may affect shipping costs'
          end

          validation
        end
      end
    end
  end

  def self.get_bulk_line_item_operations(cart_id, operations)
    cache_key = "#{CACHE_KEY_PREFIX}:bulk_operations:#{cart_id}:#{operations.hash}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_management') do
        with_retry do
          results = []
          errors = []

          operations.each do |operation|
            begin
              case operation[:action]
              when 'add'
                product = Product.find(operation[:product_id])
                cart = Cart.find(cart_id)
                result = create_line_item(product, cart, operation[:quantity], operation[:attributes] || {})
                results << result if result
              when 'update'
                line_item = LineItem.find(operation[:line_item_id])
                result = update_line_item(line_item, operation[:attributes])
                results << result if result
              when 'remove'
                line_item = LineItem.find(operation[:line_item_id])
                result = delete_line_item(line_item)
                results << result if result
              else
                errors << "Unknown operation: #{operation[:action]}"
              end
            rescue => e
              errors << "Failed to execute #{operation[:action]}: #{e.message}"
            end
          end

          EventPublisher.publish('line_item.bulk_operations_completed', {
            cart_id: cart_id,
            operations_count: operations.count,
            successful_operations: results.count,
            errors_count: errors.count,
            completed_at: Time.current
          })

          clear_cart_cache(cart_id)
          { results: results, errors: errors }
        end
      end
    end
  end

  private

  def self.clear_cart_cache(cart_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:cart_items:#{cart_id}",
      "#{CACHE_KEY_PREFIX}:cart_summary:#{cart_id}",
      "#{CACHE_KEY_PREFIX}:bulk_operations:#{cart_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end

  def self.clear_product_cache(product_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:product_items:#{product_id}",
      "#{CACHE_KEY_PREFIX}:product_availability:#{product_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end