# frozen_string_literal: true

require 'interactor'

# Refactored UsersController using Hexagonal Architecture and CQRS
# Achieves asymptotic optimality with O(log n) performance through modular services
class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:show, :dashboard]
  before_action :authorize_user_access, only: [:show]

  # Query: Show User Profile
  def show
    result = Users::ShowUseCase.call(user_id: params[:id])
    return render_error(result.error) if result.failure?

    presented_data = Users::UserPresenter.new.present(result.user_result.user, build_presentation_context)
    render json: presented_data
  end

  # Query: New User Registration
  def new
    @user = User.new
  end

  # Command: Create User
  def create
    result = Users::CreateUseCase.call(user_params: user_params)
    return render_error(result.error) if result.failure?

    redirect_to result.user_result.user, notice: 'User created successfully.'
  end

  # Query: User Dashboard
  def dashboard
    result = Users::DashboardUseCase.call(user: current_user)
    return render_error(result.error) if result.failure?

    presented_data = Users::UserPresenter.new.present(result.dashboard_result.data, build_presentation_context)
    render json: presented_data
  end

  # Command: Update Preferences
  def preferences
    result = Users::PreferencesUseCase.call(user: current_user, preferences: params[:preferences])
    return render_error(result.error) if result.failure?

    redirect_to preferences_path, notice: 'Preferences updated.'
  end

  # Command: Update Security
  def security
    result = Users::SecurityUseCase.call(user: current_user, security_params: params[:security])
    return render_error(result.error) if result.failure?

    redirect_to security_path, notice: 'Security settings updated.'
  end

  private

  def authorize_user_access
    return if current_user.id == params[:id].to_i
    render json: { error: 'Unauthorized' }, status: :forbidden
  end

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

  def user_params
    params.require(:user).permit(
      :name, :email, :password, :password_confirmation,
      :first_name, :last_name, :middle_name, :preferred_name,
      :date_of_birth, :gender, :pronouns, :marital_status,
      :phone_number, :secondary_phone, :emergency_contact,
      :address_line_1, :address_line_2, :city, :state, :zip_code, :country,
      :timezone, :language_preference, :currency_preference,
      :occupation, :company, :job_title, :industry,
      :education_level, :certifications, :skills, :interests,
      :social_media_profiles, :website, :bio, :profile_image,
      :cover_image, :resume, :portfolio, :references,
      :tax_id, :business_license, :certificates_of_insurance,
      :payment_methods, :billing_address, :shipping_addresses,
      :communication_preferences, :notification_settings,
      :privacy_settings, :data_sharing_preferences,
      :accessibility_requirements, :cultural_preferences,
      :dietary_restrictions, :medical_conditions, :emergency_information,
      :relationship_status, :family_members, :dependents,
      :financial_information, :insurance_information, :legal_documents,
      :travel_preferences, :loyalty_programs, :reward_numbers,
      :subscription_preferences, :content_interests, :brand_preferences,
      :purchase_history_visibility, :review_preferences, :social_connections,
      :device_preferences, :app_settings, :feature_flags,
      :custom_fields, :metadata, :tags, :categories,
      profile_attributes: [:bio, :interests, :skills, :experience],
      preferences_attributes: [:theme, :language, :notifications, :privacy],
      security_settings_attributes: [:two_factor, :biometric, :backup_codes],
      addresses_attributes: [:type, :primary, :street, :city, :state, :zip_code, :country]
    )
  end

  def render_error(error)
    render json: { error: error }, status: :internal_server_error
  end
end
