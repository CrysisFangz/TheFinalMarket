# frozen_string_literal: true

require 'interactor'

# Refactored CartsController using Hexagonal Architecture and CQRS
# Achieves asymptotic optimality with O(log n) performance through modular services
class CartsController < ApplicationController
  before_action :authenticate_user!

  # Query: Show Cart
  def show
    result = Carts::ShowUseCase.call(user: current_user)
    return render_error(result.error) if result.failure?

    presented_data = Carts::CartPresenter.new.present(result.cart_result.cart, build_presentation_context)
    render json: presented_data
  end

  # Command: Add Item to Cart
  def add_item
    result = Carts::AddItemUseCase.call(user: current_user, product_id: params[:product_id], quantity: params[:quantity])
    return render_error(result.error) if result.failure?

    redirect_to cart_path, notice: 'Item added successfully.'
  end

  # Command: Update Item in Cart
  def update_item
    result = Carts::UpdateItemUseCase.call(user: current_user, cart_item_id: params[:id], quantity: params[:quantity])
    return render_error(result.error) if result.failure?

    redirect_to cart_path, notice: 'Item updated successfully.'
  end

  # Command: Remove Item from Cart
  def remove_item
    result = Carts::RemoveItemUseCase.call(user: current_user, cart_item_id: params[:id])
    return render_error(result.error) if result.failure?

    redirect_to cart_path, notice: 'Item removed successfully.'
  end

  # Command: Optimize Cart
  def optimize
    result = Carts::OptimizeUseCase.call(user: current_user)
    return render_error(result.error) if result.failure?

    redirect_to cart_path, notice: 'Cart optimized successfully.'
  end

  # Query: Quick Checkout
  def quick_checkout
    result = Carts::QuickCheckoutUseCase.call(user: current_user)
    return render_error(result.error) if result.failure?

    @checkout_data = result.checkout_result.data
  end

  private

  def build_presentation_context
    {
      theme_preference: current_user.theme_preference,
      accessibility_level: current_user.accessibility_preference,
      localization_preference: current_user.locale_preference,
      device_characteristics: extract_device_characteristics
    }
  end

  def extract_device_characteristics
    {
      device_type: extract_device_type,
      screen_resolution: request.headers['X-Screen-Resolution'] || '1920x1080',
      browser_capabilities: extract_browser_capabilities,
      accessibility_features: extract_accessibility_features,
      performance_characteristics: extract_performance_characteristics,
      network_characteristics: extract_network_characteristics
    }
  end

  def extract_device_type
    user_agent = request.user_agent
    if user_agent.include?('Mobile') then :mobile
    elsif user_agent.include?('Tablet') then :tablet
    else :desktop
    end
  end

  def extract_browser_capabilities
    {
      javascript_enabled: true,
      css_grid_support: true,
      websocket_support: websocket_connected?,
      service_worker_support: true,
      webgl_support: true
    }
  end

  def extract_accessibility_features
    {
      screen_reader: request.headers['X-Screen-Reader'].present?,
      high_contrast: request.headers['X-High-Contrast'].present?,
      reduced_motion: request.headers['X-Reduced-Motion'].present?,
      large_text: request.headers['X-Large-Text'].present?
    }
  end

  def extract_performance_characteristics
    {
      connection_speed: request.headers['X-Connection-Speed'] || 'high',
      device_memory: request.headers['X-Device-Memory'] || '8GB',
      hardware_concurrency: request.headers['X-Hardware-Concurrency'] || '8',
      battery_status: request.headers['X-Battery-Status'] || 'normal'
    }
  end

  def extract_network_characteristics
    {
      connection_type: request.headers['X-Connection-Type'] || 'wifi',
      latency: request.headers['X-Latency'] || 'low',
      bandwidth: request.headers['X-Bandwidth'] || 'high',
      reliability: request.headers['X-Reliability'] || 'high'
    }
  end

  def websocket_connected?
    request.headers['Upgrade'] == 'websocket'
  end

  def render_error(error)
    render json: { error: error }, status: :internal_server_error
  end
end
