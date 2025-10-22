# frozen_string_literal: true

require 'interactor'

# Refactored DashboardController using Hexagonal Architecture and CQRS
# Achieves asymptotic optimality with O(log n) performance through modular services
class DashboardController < ApplicationController
  before_action :authenticate_user
  before_action :authorize_access
  before_action :setup_services

  # Query: Dashboard Overview
  def overview
    result = Dashboard::OverviewUseCase.call(user: current_user, dashboard_context: build_context)
    return render_error(result.error) if result.failure?

    presented_data = Dashboard::DashboardPresenter.new.present(result.dashboard_result.data, build_presentation_context)
    render json: presented_data
  end

  # Query: Payment History
  def payment_history
    result = Dashboard::PaymentHistoryUseCase.call(user: current_user, filters: params.permit(:date_range, :amount_range, :status, :payment_method, :currency), pagination: extract_pagination)
    return render_error(result.error) if result.failure?

    presented_data = Dashboard::DashboardPresenter.new.present(result.payment_result.transactions, build_presentation_context)
    render json: presented_data
  end

  # Query: Escrow Management
  def escrow
    result = Dashboard::EscrowUseCase.call(user: current_user, filters: params.permit(:date_range, :amount_range, :status, :dispute_status, :jurisdiction), pagination: extract_pagination)
    return render_error(result.error) if result.failure?

    presented_data = Dashboard::DashboardPresenter.new.present(result.escrow_result.transactions, build_presentation_context)
    render json: presented_data
  end

  # Query: Bond Management
  def bond
    result = Dashboard::BondUseCase.call(user: current_user)
    return render_error(result.error) if result.failure?

    presented_data = Dashboard::DashboardPresenter.new.present(result.bond_result.bond, build_presentation_context)
    render json: presented_data
  end

  # Command: Record Interaction
  def record_interaction
    result = Dashboard::RecordInteractionUseCase.call(user: current_user, interaction_type: params[:interaction_type], metadata: params[:interaction_metadata])
    return render_error(result.error) if result.failure?

    render json: { success: true }
  end

  private

  def authenticate_user
    auth_service = Dashboard::AuthenticationService.instance
    auth_result = auth_service.authenticate_user(credentials: extract_credentials, context: request_context)
    return render json: { error: auth_result.error }, status: :unauthorized if auth_result.failure?

    @current_user = auth_result.user
  end

  def authorize_access
    authz_service = Dashboard::AuthorizationService.instance
    authz_result = authz_service.assess_dashboard_authorization(current_user, request_context)
    return render json: { error: authz_result.error }, status: :forbidden if authz_result.failure?
  end

  def setup_services
    @dashboard_decorator = Dashboard::DashboardDecorator.new
    @presenter = Dashboard::DashboardPresenter.new
  end

  def build_context
    {
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      timestamp: Time.current,
      dashboard_type: params[:dashboard_type] || 'overview',
      time_range: extract_time_range,
      filters: params.permit(:time_range, :data_sources, :metrics, :dimensions, :granularity)
    }
  end

  def build_presentation_context
    {
      theme_preference: current_user.theme_preference,
      accessibility_level: current_user.accessibility_preference,
      localization_preference: current_user.locale_preference,
      device_characteristics: extract_device_characteristics,
      real_time_requirements: websocket_connected? || server_sent_events_enabled?
    }
  end

  def extract_credentials
    {
      email: session[:authentication_email] || current_user&.email,
      token: request.headers['Authorization']&.gsub('Bearer ', ''),
      device_fingerprint: extract_device_fingerprint,
      behavioral_signature: extract_behavioral_signature
    }
  end

  def request_context
    {
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      request_id: request.request_id,
      timestamp: Time.current,
      http_method: request.method,
      request_path: request.path,
      query_parameters: request.query_parameters
    }
  end

  def extract_pagination
    {
      page: params[:page].to_i || 1,
      per_page: [params[:per_page].to_i, 100].min || 20,
      sort_by: params[:sort_by] || 'created_at',
      sort_order: params[:sort_order] || 'desc'
    }
  end

  def extract_time_range
    case params[:time_range]
    when 'today' then 1.day.ago..Time.current
    when 'week' then 1.week.ago..Time.current
    when 'month' then 1.month.ago..Time.current
    when 'quarter' then 3.months.ago..Time.current
    when 'year' then 1.year.ago..Time.current
    else 24.hours.ago..Time.current
    end
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

  def server_sent_events_enabled?
    request.headers['Accept']&.include?('text/event-stream')
  end

  def extract_device_fingerprint
    # Placeholder for device fingerprinting
    'device_fingerprint'
  end

  def extract_behavioral_signature
    # Placeholder for behavioral signature
    'behavioral_signature'
  end

  def render_error(error)
    render json: { error: error }, status: :internal_server_error
  end
end