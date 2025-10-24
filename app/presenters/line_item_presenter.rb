class LineItemPresenter
  include CircuitBreaker
  include Retryable

  def initialize(line_item)
    @line_item = line_item
  end

  def as_json(options = {})
    cache_key = "line_item_presenter:#{@line_item.id}:#{@line_item.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      with_circuit_breaker('line_item_presenter') do
        with_retry do
          {
            id: @line_item.id,
            quantity: @line_item.quantity,
            created_at: @line_item.created_at,
            updated_at: @line_item.updated_at,
            product: product_data,
            cart: cart_data,
            pricing: pricing_data,
            availability: availability_data,
            recommendations: recommendations_data
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

  def to_cart_response
    as_json.merge(
      cart_data: {
        can_update: can_update?,
        can_delete: can_delete?,
        max_quantity: max_quantity_allowed,
        quantity_validation: validate_quantity(@line_item.quantity),
        alternatives: suggest_alternatives
      }
    )
  end

  private

  def product_data
    Rails.cache.fetch("line_item_product:#{@line_item.product_id}", expires_in: 30.minutes) do
      with_circuit_breaker('product_data') do
        with_retry do
          {
            id: @line_item.product.id,
            name: @line_item.product.name,
            sku: @line_item.product.sku,
            price: @line_item.product.price,
            sale_price: @line_item.product.sale_price,
            currency: 'USD',
            condition: @line_item.product.condition,
            availability: @line_item.product.availability,
            images: @line_item.product.images.first&.url,
            category: @line_item.product.category&.name
          }
        end
      end
    end
  end

  def cart_data
    Rails.cache.fetch("line_item_cart:#{@line_item.cart_id}", expires_in: 15.minutes) do
      with_circuit_breaker('cart_data') do
        with_retry do
          cart = @line_item.cart

          {
            id: cart.id,
            user_id: cart.user_id,
            item_count: cart.line_items.count,
            total_quantity: cart.line_items.sum(:quantity),
            status: cart.status,
            created_at: cart.created_at,
            expires_at: cart.expires_at
          }
        end
      end
    end
  end

  def pricing_data
    Rails.cache.fetch("line_item_pricing:#{@line_item.id}", expires_in: 10.minutes) do
      with_circuit_breaker('pricing_data') do
        with_retry do
          LineItemPricingService.calculate_total_price(@line_item)
        end
      end
    end
  end

  def availability_data
    Rails.cache.fetch("line_item_availability:#{@line_item.product_id}", expires_in: 10.minutes) do
      with_circuit_breaker('availability_data') do
        with_retry do
          LineItemManagementService.get_product_availability(@line_item.product_id)
        end
      end
    end
  end

  def recommendations_data
    Rails.cache.fetch("line_item_recommendations:#{@line_item.id}", expires_in: 15.minutes) do
      with_circuit_breaker('recommendations_data') do
        with_retry do
          {
            quantity_optimization: suggest_quantity_optimization,
            bundle_suggestions: suggest_bundles,
            alternative_products: suggest_alternatives,
            discount_opportunities: find_discount_opportunities,
            shipping_optimization: suggest_shipping_optimization
          }
        end
      end
    end
  end

  def can_update?
    @line_item.cart.status == 'active' && !@line_item.cart.expired?
  end

  def can_delete?
    @line_item.cart.status == 'active' && !@line_item.cart.expired?
  end

  def max_quantity_allowed
    availability = availability_data
    availability[:available_quantity] + @line_item.quantity
  end

  def validate_quantity(quantity)
    validation = LineItemManagementService.validate_line_item_quantity(@line_item, quantity)

    {
      valid: validation[:valid],
      warnings: validation[:warnings],
      errors: validation[:errors],
      max_allowed: max_quantity_allowed,
      min_allowed: 1
    }
  end

  def suggest_alternatives
    Rails.cache.fetch("line_item_alternatives:#{@line_item.product_id}", expires_in: 20.minutes) do
      with_circuit_breaker('suggest_alternatives') do
        with_retry do
          # Find similar products in same category
          similar_products = Product.where(category_id: @line_item.product.category_id)
                                  .where.not(id: @line_item.product_id)
                                  .where(status: :active)
                                  .limit(3)
                                  .map do |product|
                                    {
                                      id: product.id,
                                      name: product.name,
                                      price: product.price,
                                      availability: product.availability,
                                      similarity_score: calculate_similarity_score(@line_item.product, product)
                                    }
                                  end

          similar_products.sort_by { |p| -p[:similarity_score] }
        end
      end
    end
  end

  def suggest_quantity_optimization
    pricing = pricing_data
    availability = availability_data

    suggestions = []

    # Suggest quantity for better discounts
    if @line_item.quantity < 10
      bulk_pricing = LineItemPricingService.get_price_comparison(@line_item.product_id, 10)
      if bulk_pricing[:savings] > 0
        suggestions << {
          type: 'bulk_discount',
          current_quantity: @line_item.quantity,
          suggested_quantity: 10,
          potential_savings: bulk_pricing[:savings],
          message: "Add #{10 - @line_item.quantity} more items to get bulk discount"
        }
      end
    end

    # Suggest quantity based on availability
    if @line_item.quantity >= availability[:available_quantity]
      suggestions << {
        type: 'availability',
        current_quantity: @line_item.quantity,
        max_available: availability[:available_quantity],
        message: "Only #{availability[:available_quantity]} items available"
      }
    end

    suggestions
  end

  def suggest_bundles
    # Suggest product bundles or related items
    bundles = []

    # Look for bundle deals in same category
    category_products = Product.where(category_id: @line_item.product.category_id)
                              .where(status: :active)
                              .limit(5)

    category_products.each do |product|
      next if product.id == @line_item.product_id

      bundle_savings = calculate_bundle_savings(@line_item.product, product)
      if bundle_savings > 0
        bundles << {
          product_id: product.id,
          product_name: product.name,
          bundle_savings: bundle_savings,
          message: "Save #{bundle_savings} when purchased together"
        }
      end
    end

    bundles.first(3)
  end

  def find_discount_opportunities
    opportunities = []

    # Check for time-based discounts
    if Time.current.hour.between?(18, 23) # Evening hours
      opportunities << {
        type: 'time_based',
        discount_type: 'evening_special',
        discount_amount: @line_item.product.price * 0.05,
        message: '5% evening discount available',
        valid_until: Time.current.end_of_day
      }
    end

    # Check for first-time buyer discount
    if @line_item.cart.user.orders.count == 0
      opportunities << {
        type: 'first_time',
        discount_type: 'welcome_discount',
        discount_amount: @line_item.product.price * 0.1,
        message: '10% first purchase discount',
        valid_until: 30.days.from_now
      }
    end

    opportunities
  end

  def suggest_shipping_optimization
    shipping_options = LineItemPricingService.get_price_comparison(@line_item.product_id, @line_item.quantity)[:shipping_options]

    {
      options: shipping_options[:options],
      cheapest: shipping_options[:cheapest],
      fastest: shipping_options[:fastest],
      recommendation: recommend_shipping_option(shipping_options)
    }
  end

  def calculate_similarity_score(product1, product2)
    score = 0

    # Same category
    score += 30 if product1.category_id == product2.category_id

    # Similar price range
    price_diff = (product1.price - product2.price).abs
    if price_diff < product1.price * 0.2
      score += 25
    elsif price_diff < product1.price * 0.5
      score += 15
    end

    # Similar condition
    score += 20 if product1.condition == product2.condition

    # Similar availability
    score += 15 if product1.availability == product2.availability

    # Same seller
    score += 10 if product1.user_id == product2.user_id

    score
  end

  def calculate_bundle_savings(product1, product2)
    # Calculate savings for buying products together
    # This would check for bundle pricing rules
    0 # Simplified for now
  end

  def recommend_shipping_option(shipping_options)
    # Recommend based on balance of cost and speed
    options = shipping_options[:options]

    # Find best value option
    best_value = options.min_by do |option|
      # Weight: 70% cost, 30% speed
      option[:price] * 0.7 + (6 - option[:estimated_days]) * 2
    end

    {
      recommended_method: best_value[:method],
      reason: 'Best balance of cost and delivery speed',
      savings_vs_fastest: shipping_options[:fastest][:price] - best_value[:price],
      time_vs_cheapest: best_value[:estimated_days] - shipping_options[:cheapest][:estimated_days]
    }
  end
end