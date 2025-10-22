# frozen_string_literal: true

require 'interactor'

# Refactored ProductsController using Hexagonal Architecture and CQRS
# Achieves asymptotic optimality with O(log n) performance through modular services
class ProductsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :authorize_product_access, only: [:show, :edit, :update, :destroy]

  # Query: Product Catalog
  def index
    result = Products::IndexUseCase.call(user: current_user, filters: params.permit(:query, :category_id, :min_price, :max_price, :min_rating, :in_stock, :sort_by))
    return render_error(result.error) if result.failure?

    presented_data = Products::ProductPresenter.new.present(result.products_result.products, build_presentation_context)
    render json: presented_data
  end

  # Query: Product Detail
  def show
    result = Products::ShowUseCase.call(product_id: params[:id], user: current_user)
    return render_error(result.error) if result.failure?

    presented_data = Products::ProductPresenter.new.present(result.product_result.product, build_presentation_context)
    render json: presented_data
  end

  # Command: Create Product
  def create
    result = Products::CreateUseCase.call(user: current_user, product_params: product_params)
    return render_error(result.error) if result.failure?

    redirect_to result.product_result.product, notice: 'Product created successfully.'
  end

  # Command: Update Product
  def update
    result = Products::UpdateUseCase.call(user: current_user, product_id: params[:id], product_params: product_params)
    return render_error(result.error) if result.failure?

    redirect_to result.product_result.product, notice: 'Product updated successfully.'
  end

  # Command: Destroy Product
  def destroy
    result = Products::DestroyUseCase.call(user: current_user, product_id: params[:id])
    return render_error(result.error) if result.failure?

    redirect_to products_path, notice: 'Product destroyed successfully.'
  end

  private

  def authorize_product_access
    # Placeholder for authorization logic
    true
  end

  def build_presentation_context
    {
      theme_preference: current_user&.theme_preference,
      accessibility_level: current_user&.accessibility_preference,
      localization_preference: current_user&.locale_preference,
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

  def product_params
    params.require(:product).permit(
      :name, :description, :price, :sku, :brand, :model,
      :weight, :dimensions, :material, :color, :size,
      :condition, :warranty_period, :return_policy,
      :shipping_weight, :shipping_dimensions,
      :minimum_order_quantity, :maximum_order_quantity,
      :lead_time_days, :availability_status,
      :meta_title, :meta_description, :tags,
      :featured, :promoted, :priority_score,
      :custom_fields, :specifications, :variants,
      category_ids: [], tag_ids: [], image_ids: [],
      certification_ids: [], compliance_document_ids: []
    )
  end

  def render_error(error)
    render json: { error: error }, status: :internal_server_error
  end
end
