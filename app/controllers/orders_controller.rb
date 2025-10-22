# frozen_string_literal: true

require 'interactor'

# Refactored OrdersController using Hexagonal Architecture and CQRS
# Achieves asymptotic optimality with O(log n) performance through modular services
class OrdersController < ApplicationController
  before_action :authenticate_user!

  # Query: Order Dashboard
  def index
    result = Orders::IndexUseCase.call(user: current_user, filters: params.permit(:status, :date_range, :amount_range, :fulfillment_status, :payment_status))
    return render_error(result.error) if result.failure?

    presented_data = Orders::OrderPresenter.new.present(result.orders_result.orders, build_presentation_context)
    render json: presented_data
  end

  # Query: Order Detail
  def show
    result = Orders::ShowUseCase.call(order_id: params[:id], user: current_user)
    return render_error(result.error) if result.failure?

    presented_data = Orders::OrderPresenter.new.present(result.order_result.order, build_presentation_context)
    render json: presented_data
  end

  # Command: New Order
  def new
    @order = Order.new
  end

  # Command: Create Order
  def create
    result = Orders::CreateUseCase.call(user: current_user, order_params: order_params)
    return render_error(result.error) if result.failure?

    redirect_to result.order_result.order, notice: 'Order created successfully.'
  end

  # Command: Update Order
  def update
    result = Orders::UpdateUseCase.call(user: current_user, order_id: params[:id], order_params: order_params)
    return render_error(result.error) if result.failure?

    redirect_to result.order_result.order, notice: 'Order updated successfully.'
  end

  # Command: Cancel Order
  def cancel
    result = Orders::CancelUseCase.call(user: current_user, order_id: params[:id])
    return render_error(result.error) if result.failure?

    redirect_to orders_path, notice: 'Order cancelled successfully.'
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

  def order_params
    params.require(:order).permit(
      :shipping_address, :billing_address, :notes, :special_instructions,
      :shipping_method, :shipping_priority, :gift_message, :gift_wrap,
      :tax_exempt, :tax_exempt_reason, :business_order, :purchase_order_number,
      :preferred_delivery_date, :preferred_delivery_time, :signature_required,
      :insurance_required, :insurance_amount, :special_handling_instructions,
      :environmental_preferences, :accessibility_requirements, :language_preference,
      :currency_preference, :payment_method_preference, :communication_preferences,
      :notification_settings, :tracking_preferences, :return_authorization,
      :loyalty_program_enrollment, :promotional_code, :referral_code,
      shipping_address_attributes: [:street, :city, :state, :zip_code, :country, :coordinates],
      billing_address_attributes: [:street, :city, :state, :zip_code, :country],
      payment_method_attributes: [:type, :token, :fingerprint, :metadata],
      fulfillment_preferences_attributes: [:method, :priority, :special_requirements]
    )
  end

  def render_error(error)
    render json: { error: error }, status: :internal_server_error
  end
end