class LineItemPricingService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'line_item_pricing'
  CACHE_TTL = 10.minutes

  def self.calculate_total_price(line_item)
    cache_key = "#{CACHE_KEY_PREFIX}:total_price:#{line_item.id}:#{line_item.quantity}:#{line_item.product.price}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_pricing') do
        with_retry do
          base_price = line_item.product.price
          quantity = line_item.quantity

          # Apply any discounts
          discount_amount = calculate_discount_amount(line_item)
          discounted_price = base_price - discount_amount

          # Apply taxes
          tax_amount = calculate_tax_amount(line_item, discounted_price)

          # Apply shipping (if applicable)
          shipping_amount = calculate_shipping_amount(line_item)

          total_price = (discounted_price * quantity) + tax_amount + shipping_amount

          pricing_breakdown = {
            base_price: base_price,
            quantity: quantity,
            subtotal: base_price * quantity,
            discount_amount: discount_amount,
            discounted_subtotal: discounted_price * quantity,
            tax_amount: tax_amount,
            shipping_amount: shipping_amount,
            total_price: total_price,
            currency: 'USD'
          }

          EventPublisher.publish('line_item.pricing_calculated', {
            line_item_id: line_item.id,
            product_id: line_item.product_id,
            cart_id: line_item.cart_id,
            base_price: base_price,
            quantity: quantity,
            discount_amount: discount_amount,
            tax_amount: tax_amount,
            shipping_amount: shipping_amount,
            total_price: total_price,
            calculated_at: Time.current
          })

          pricing_breakdown
        end
      end
    end
  end

  def self.calculate_bulk_pricing(cart_id)
    cache_key = "#{CACHE_KEY_PREFIX}:bulk_pricing:#{cart_id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_pricing') do
        with_retry do
          line_items = LineItemManagementService.get_line_items_for_cart(cart_id)

          bulk_pricing = {
            item_count: line_items.count,
            total_quantity: line_items.sum(:quantity),
            subtotal: 0,
            total_discounts: 0,
            total_taxes: 0,
            total_shipping: 0,
            total_price: 0,
            items: []
          }

          line_items.each do |line_item|
            pricing = calculate_total_price(line_item)

            bulk_pricing[:subtotal] += pricing[:subtotal]
            bulk_pricing[:total_discounts] += pricing[:discount_amount] * line_item.quantity
            bulk_pricing[:total_taxes] += pricing[:tax_amount]
            bulk_pricing[:total_shipping] += pricing[:shipping_amount]
            bulk_pricing[:total_price] += pricing[:total_price]

            bulk_pricing[:items] << {
              line_item_id: line_item.id,
              product_id: line_item.product_id,
              product_name: line_item.product.name,
              quantity: line_item.quantity,
              pricing: pricing
            }
          end

          # Apply bulk discounts
          bulk_discount = calculate_bulk_discount(bulk_pricing)
          bulk_pricing[:bulk_discount] = bulk_discount
          bulk_pricing[:total_price] -= bulk_discount

          EventPublisher.publish('line_item.bulk_pricing_calculated', {
            cart_id: cart_id,
            item_count: bulk_pricing[:item_count],
            total_quantity: bulk_pricing[:total_quantity],
            subtotal: bulk_pricing[:subtotal],
            total_discounts: bulk_pricing[:total_discounts],
            bulk_discount: bulk_discount,
            total_taxes: bulk_pricing[:total_taxes],
            total_shipping: bulk_pricing[:total_shipping],
            total_price: bulk_pricing[:total_price],
            calculated_at: Time.current
          })

          bulk_pricing
        end
      end
    end
  end

  def self.get_price_comparison(product_id, quantity = 1)
    cache_key = "#{CACHE_KEY_PREFIX}:price_comparison:#{product_id}:#{quantity}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_pricing') do
        with_retry do
          product = Product.find(product_id)

          comparison = {
            product_id: product_id,
            product_name: product.name,
            quantity: quantity,
            base_price: product.price,
            unit_price: product.price,
            total_base_price: product.price * quantity,
            discounts: get_applicable_discounts(product, quantity),
            taxes: calculate_tax_breakdown(product, product.price * quantity),
            shipping_options: get_shipping_options(product, quantity),
            final_price: 0,
            savings: 0
          }

          # Calculate final price after all adjustments
          discounted_price = comparison[:total_base_price] - comparison[:discounts][:total_discount]
          comparison[:final_price] = discounted_price + comparison[:taxes][:total_tax] + comparison[:shipping_options][:cheapest][:price]
          comparison[:savings] = comparison[:total_base_price] - comparison[:final_price]

          EventPublisher.publish('line_item.price_comparison_generated', {
            product_id: product_id,
            quantity: quantity,
            base_price: comparison[:total_base_price],
            final_price: comparison[:final_price],
            savings: comparison[:savings],
            generated_at: Time.current
          })

          comparison
        end
      end
    end
  end

  def self.get_pricing_history(product_id, days = 30)
    cache_key = "#{CACHE_KEY_PREFIX}:pricing_history:#{product_id}:#{days}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('line_item_pricing') do
        with_retry do
          # This would require price change history
          # For now, return current pricing
          history = {
            current_price: Product.find(product_id).price,
            price_changes: [],
            average_price: Product.find(product_id).price,
            price_volatility: 'stable',
            last_updated: Time.current
          }

          EventPublisher.publish('line_item.pricing_history_retrieved', {
            product_id: product_id,
            days: days,
            current_price: history[:current_price],
            retrieved_at: Time.current
          })

          history
        end
      end
    end
  end

  private

  def self.calculate_discount_amount(line_item)
    product = line_item.product
    quantity = line_item.quantity

    discount_amount = 0

    # Product-specific discounts
    if product.sale_price && product.sale_price < product.price
      discount_amount += (product.price - product.sale_price) * quantity
    end

    # Quantity-based discounts
    if quantity >= 10
      discount_amount += (product.price * quantity * 0.05) # 5% discount for 10+ items
    end

    # Category-based discounts
    if product.category&.fee_type == 'no_fee'
      discount_amount += (product.price * quantity * 0.1) # 10% discount for no-fee categories
    end

    discount_amount
  end

  def self.calculate_tax_amount(line_item, price)
    # This would integrate with tax calculation service
    # For now, use simple calculation
    tax_rate = 0.08 # 8% tax rate
    price * tax_rate
  end

  def self.calculate_shipping_amount(line_item)
    # This would integrate with shipping calculation service
    # For now, use simple calculation based on weight and quantity
    product = line_item.product
    quantity = line_item.quantity

    base_shipping = 5.99
    weight_shipping = (product.weight || 1) * quantity * 0.5
    quantity_shipping = quantity > 1 ? (quantity - 1) * 1.0 : 0

    [base_shipping + weight_shipping + quantity_shipping, 0].max
  end

  def self.calculate_bulk_discount(bulk_pricing)
    subtotal = bulk_pricing[:subtotal]
    item_count = bulk_pricing[:item_count]

    # Bulk discount tiers
    if subtotal >= 500
      subtotal * 0.1 # 10% discount for $500+
    elsif subtotal >= 200
      subtotal * 0.05 # 5% discount for $200+
    elsif item_count >= 10
      subtotal * 0.03 # 3% discount for 10+ items
    else
      0
    end
  end

  def self.get_applicable_discounts(product, quantity)
    discounts = {
      product_discount: 0,
      quantity_discount: 0,
      category_discount: 0,
      total_discount: 0
    }

    # Product discount
    if product.sale_price && product.sale_price < product.price
      discounts[:product_discount] = (product.price - product.sale_price) * quantity
    end

    # Quantity discount
    if quantity >= 10
      discounts[:quantity_discount] = product.price * quantity * 0.05
    end

    # Category discount
    if product.category&.fee_type == 'no_fee'
      discounts[:category_discount] = product.price * quantity * 0.1
    end

    discounts[:total_discount] = discounts.values.sum
    discounts
  end

  def self.calculate_tax_breakdown(product, subtotal)
    # This would integrate with tax service for detailed breakdown
    tax_rate = 0.08

    {
      subtotal: subtotal,
      tax_rate: tax_rate,
      total_tax: subtotal * tax_rate,
      breakdown: {
        state_tax: subtotal * 0.06,
        local_tax: subtotal * 0.02
      }
    }
  end

  def self.get_shipping_options(product, quantity)
    # This would integrate with shipping service
    options = [
      {
        method: 'standard',
        name: 'Standard Shipping',
        price: calculate_shipping_amount(OpenStruct.new(product: product, quantity: quantity)),
        estimated_days: 5
      },
      {
        method: 'express',
        name: 'Express Shipping',
        price: calculate_shipping_amount(OpenStruct.new(product: product, quantity: quantity)) * 1.5,
        estimated_days: 2
      },
      {
        method: 'overnight',
        name: 'Overnight Shipping',
        price: calculate_shipping_amount(OpenStruct.new(product: product, quantity: quantity)) * 2.5,
        estimated_days: 1
      }
    ]

    {
      options: options,
      cheapest: options.min_by { |opt| opt[:price] },
      fastest: options.min_by { |opt| opt[:estimated_days] }
    }
  end

  def self.clear_pricing_cache(product_id, cart_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:total_price:#{product_id}",
      "#{CACHE_KEY_PREFIX}:bulk_pricing:#{cart_id}",
      "#{CACHE_KEY_PREFIX}:price_comparison:#{product_id}",
      "#{CACHE_KEY_PREFIX}:pricing_history:#{product_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end