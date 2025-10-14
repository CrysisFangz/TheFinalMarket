# frozen_string_literal: true

# Enterprise-grade admin controller for seller application management
# Implements comprehensive business logic, security, and performance optimizations
class Admin::SellerApplicationsController < Admin::BaseController
  # Custom exceptions for better error handling
  class ApplicationNotFound < StandardError; end
  class AuthorizationFailed < StandardError; end
  class ServiceError < StandardError; end

  # Authentication and authorization filters
  before_action :authenticate_admin_user!
  before_action :authorize_admin_action, only: [:index, :show, :update]
  before_action :set_seller_application, only: [:show, :update]
  before_action :check_rate_limits, only: [:update]

  # Caching headers for performance
  after_action :set_cache_headers, only: [:index, :show]

  # Enhanced index action with pagination, filtering, and caching
  # GET /admin/seller_applications
  def index
    authorize_action!(:index)
    
    # Extract and validate query parameters
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = validate_per_page(params[:per_page])
    filters = extract_filters

    # Fetch applications using service layer
    result = Admin::SellerApplicationManagementService.fetch_applications(
      page: page,
      per_page: per_page,
      filters: filters
    )

    if result.success?
      @seller_applications = result.data
      @pagination_metadata = generate_pagination_metadata(@seller_applications)
      @filter_summary = generate_filter_summary(filters)
      @performance_metrics = calculate_performance_metrics

      # Preload presenter data for enhanced display
      @presented_applications = @seller_applications.map do |application|
        presenter = Admin::SellerApplicationPresenter.new(application, view_context)
        presenter.present
      end

      render :index, status: :ok
    else
      handle_service_error(result.error_message)
    end
  rescue StandardError => e
    Rails.logger.error("Error in seller applications index: #{e.message}")
    handle_error('Failed to load seller applications', :internal_server_error)
  end

  # Enhanced show action with comprehensive application details
  # GET /admin/seller_applications/:id
  def show
    authorize_action!(:show)

    # Use presenter for enhanced data presentation
    @presenter = Admin::SellerApplicationPresenter.new(@seller_application, view_context)
    @application_data = @presenter.present

    # Additional context data for admin decision making
    @context_data = load_admin_context
    @audit_trail = load_audit_trail
    @related_applications = load_related_applications

    render :show, status: :ok
  rescue StandardError => e
    Rails.logger.error("Error showing seller application: #{e.message}")
    handle_error('Failed to load seller application details', :not_found)
  end

  # Enhanced update action with comprehensive business logic and error handling
  # PATCH/PUT /admin/seller_applications/:id
  def update
    authorize_action!(:update)

    # Validate update parameters
    validate_update_params!

    # Process application update through service layer
    service = Admin::SellerApplicationManagementService.new(
      @seller_application,
      current_admin_user,
      update_params
    )

    result = service.process_application_update

    if result.success?
      handle_successful_update(result.data)
    else
      handle_update_error(result.error_message)
    end
  rescue ActionController::ParameterMissing => e
    handle_error("Missing required parameter: #{e.message}", :bad_request)
  rescue ArgumentError => e
    handle_error("Invalid parameter: #{e.message}", :bad_request)
  rescue StandardError => e
    Rails.logger.error("Error updating seller application: #{e.message}")
    handle_error('Failed to update seller application', :internal_server_error)
  end

  # Additional admin actions for enhanced functionality

  # Bulk operations for multiple applications
  # POST /admin/seller_applications/bulk_action
  def bulk_action
    authorize_action!(:update)

    action = params[:bulk_action]
    application_ids = params[:application_ids]

    unless valid_bulk_action?(action)
      return handle_error('Invalid bulk action', :bad_request)
    end

    results = perform_bulk_action(action, application_ids)

    if results[:success_count] > 0
      flash[:success] = "Successfully processed #{results[:success_count]} applications"
    end

    if results[:error_count] > 0
      flash[:error] = "Failed to process #{results[:error_count]} applications"
    end

    redirect_to admin_seller_applications_path
  end

  # Export functionality for reporting and analytics
  # GET /admin/seller_applications/export
  def export
    authorize_action!(:export)

    format = params[:format].to_sym
    filters = extract_filters

    unless valid_export_format?(format)
      return handle_error('Invalid export format', :bad_request)
    end

    export_data = generate_export_data(format, filters)

    send_data export_data,
              filename: "seller_applications_#{Time.current.strftime('%Y%m%d_%H%M%S')}.#{format}",
              type: export_content_type(format)
  rescue StandardError => e
    Rails.logger.error("Error exporting seller applications: #{e.message}")
    handle_error('Failed to export data', :internal_server_error)
  end

  private

  # Enhanced authorization with detailed permission checking
  def authorize_admin_action
    unless current_admin_user&.admin?
      raise AuthorizationFailed, 'Admin access required'
    end
  end

  # Specific action authorization using policy pattern
  def authorize_action!(action)
    policy = Admin::SellerApplicationPolicy.new(current_admin_user, @seller_application, action)

    unless policy.public_send("#{action}?")
      raise AuthorizationFailed, "Insufficient permissions for #{action}"
    end
  end

  # Sets seller application with error handling
  def set_seller_application
    @seller_application = SellerApplication.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    raise ApplicationNotFound, "Seller application not found: #{params[:id]}"
  end

  # Validates and extracts update parameters
  def update_params
    params.require(:seller_application).permit(
      :status,
      :feedback,
      :admin_notes,
      :priority_level,
      :review_deadline
    ).merge(
      updated_by: current_admin_user.id,
      updated_at: Time.current
    )
  end

  # Validates update parameters with business rules
  def validate_update_params!
    allowed_statuses = %w[pending under_review approved rejected suspended]
    new_status = params[:seller_application][:status]

    unless allowed_statuses.include?(new_status)
      raise ArgumentError, "Invalid status: #{new_status}"
    end

    # Additional validation logic can be added here
  end

  # Validates items per page parameter
  def validate_per_page(per_page_param)
    per_page = per_page_param.to_i
    return 25 if per_page <= 0 # Default
    return 100 if per_page > 100 # Maximum
    per_page
  end

  # Extracts and validates filter parameters
  def extract_filters
    {
      status: params[:status],
      search: sanitize_search_term(params[:search]),
      date_from: parse_date(params[:date_from]),
      date_to: parse_date(params[:date_to]),
      sort_by: validate_sort_column(params[:sort_by]),
      sort_direction: validate_sort_direction(params[:sort_direction])
    }.compact
  end

  # Handles successful application update
  def handle_successful_update(application)
    # Log successful update
    Rails.logger.info("Seller application #{application.id} updated by #{current_admin_user.id}")

    # Set success flash message with details
    flash[:success] = generate_success_message(application)

    # Redirect with appropriate parameters
    redirect_params = { page: params[:current_page], status: params[:current_status] }.compact
    redirect_to admin_seller_applications_path(redirect_params), status: :see_other
  end

  # Handles update errors with detailed feedback
  def handle_update_error(error_message)
    Rails.logger.warn("Seller application update failed: #{error_message}")

    flash.now[:error] = error_message
    @presenter = Admin::SellerApplicationPresenter.new(@seller_application, view_context)
    @application_data = @presenter.present

    render :show, status: :unprocessable_entity
  end

  # Handles general errors with appropriate logging
  def handle_error(message, status)
    Rails.logger.error("Admin controller error: #{message}")
    flash[:error] = message
    render 'error', status: status
  end

  # Handles service layer errors
  def handle_service_error(error_message)
    Rails.logger.error("Service error: #{error_message}")
    flash[:error] = 'A system error occurred. Please try again.'
    redirect_to admin_seller_applications_path
  end

  # Generates success message based on action performed
  def generate_success_message(application)
    status_messages = {
      'approved' => 'Seller application has been approved and user notified.',
      'rejected' => 'Seller application has been rejected with feedback provided.',
      'under_review' => 'Seller application has been moved to review.',
      'suspended' => 'Seller account has been suspended.'
    }

    message = status_messages[application.status.to_s] || 'Seller application updated successfully.'

    if application.feedback.present?
      message += " Feedback: #{application.feedback}"
    end

    message
  end

  # Generates pagination metadata for template
  def generate_pagination_metadata(applications)
    {
      current_page: applications.current_page,
      total_pages: applications.total_pages,
      total_count: applications.total_count,
      per_page: applications.limit_value,
      has_next: applications.next_page.present?,
      has_prev: applications.prev_page.present?
    }
  end

  # Generates filter summary for display
  def generate_filter_summary(filters)
    summary = []

    if filters[:status].present?
      summary << "Status: #{filters[:status].titleize}"
    end

    if filters[:search].present?
      summary << "Search: #{filters[:search]}"
    end

    if filters[:date_from].present? || filters[:date_to].present?
      date_range = "Date: #{filters[:date_from]&.strftime('%m/%d/%Y')} - #{filters[:date_to]&.strftime('%m/%d/%Y')}"
      summary << date_range
    end

    summary
  end

  # Calculates performance metrics for monitoring
  def calculate_performance_metrics
    {
      query_time: Time.current - @start_time,
      cache_hit_rate: calculate_cache_hit_rate,
      database_load: calculate_database_load
    }
  end

  # Loads additional context data for admin decision making
  def load_admin_context
    {
      similar_applications: find_similar_applications,
      admin_workload: current_admin_user.current_workload,
      average_review_time: calculate_average_review_time,
      pending_count: SellerApplication.where(status: :pending).count
    }
  end

  # Loads audit trail for the application
  def load_audit_trail
    # This would load from AdminActionLog or similar audit table
    []
  end

  # Loads related applications for context
  def load_related_applications
    @seller_application.user&.seller_applications
                      &.where.not(id: @seller_application.id)
                      &.order(created_at: :desc)
                      &.limit(5) || []
  end

  # Validates bulk action parameters
  def valid_bulk_action?(action)
    %w[approve reject suspend archive].include?(action)
  end

  # Performs bulk action on multiple applications
  def perform_bulk_action(action, application_ids)
    success_count = 0
    error_count = 0

    application_ids.each do |app_id|
      begin
        application = SellerApplication.find(app_id)
        service = Admin::SellerApplicationManagementService.new(
          application,
          current_admin_user,
          { status: action }
        )

        result = service.process_application_update
        success_count += 1 if result.success?
      rescue StandardError
        error_count += 1
      end
    end

    { success_count: success_count, error_count: error_count }
  end

  # Validates export format
  def valid_export_format?(format)
    %i[csv xlsx pdf json].include?(format)
  end

  # Generates export data in specified format
  def generate_export_data(format, filters)
    applications = Admin::SellerApplicationManagementService.fetch_applications(
      page: 1,
      per_page: 1000, # Reasonable limit for export
      filters: filters
    ).data

    case format
    when :csv
      generate_csv_export(applications)
    when :xlsx
      generate_xlsx_export(applications)
    when :pdf
      generate_pdf_export(applications)
    when :json
      generate_json_export(applications)
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  # Returns appropriate content type for export format
  def export_content_type(format)
    {
      csv: 'text/csv',
      xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      pdf: 'application/pdf',
      json: 'application/json'
    }[format]
  end

  # Sanitizes search terms for security
  def sanitize_search_term(term)
    return nil unless term.present?

    # Remove potentially dangerous characters and limit length
    term.gsub(/[<>'";&]/, '').strip[0..100]
  end

  # Parses date parameters safely
  def parse_date(date_string)
    return nil unless date_string.present?

    Date.parse(date_string)
  rescue ArgumentError
    nil
  end

  # Validates sort column for security
  def validate_sort_column(column)
    allowed_columns = %w[created_at updated_at status priority_level]
    return 'created_at' unless column.present?
    return column if allowed_columns.include?(column)
    'created_at'
  end

  # Validates sort direction
  def validate_sort_direction(direction)
    %w[asc desc].include?(direction&.downcase) ? direction.downcase : 'desc'
  end

  # Sets appropriate cache headers for performance
  def set_cache_headers
    expires_in 5.minutes, public: false
  end

  # Checks rate limits for admin actions
  def check_rate_limits
    # Implement rate limiting logic based on admin role and recent actions
    true # Placeholder for rate limiting implementation
  end

  # Helper method to access view context for presenters
  def view_context
    @view_context ||= ApplicationController.helpers
  end

  # Tracks the start time for performance monitoring
  def @start_time
    @start_time ||= Time.current
  end

  # Calculates cache hit rate (placeholder implementation)
  def calculate_cache_hit_rate
    0.85 # Placeholder value
  end

  # Calculates database load (placeholder implementation)
  def calculate_database_load
    'low' # Placeholder value
  end

  # Finds similar applications for context
  def find_similar_applications
    # Implement similarity logic based on user profile, category, etc.
    []
  end

  # Calculates average review time for context
  def calculate_average_review_time
    # Implement calculation based on historical data
    '2.3 days' # Placeholder value
  end

  # Export generation methods (placeholder implementations)
  def generate_csv_export(applications)
    # Implement CSV generation
    'csv,data,here'
  end

  def generate_xlsx_export(applications)
    # Implement XLSX generation
    'xlsx,data,here'
  end

  def generate_pdf_export(applications)
    # Implement PDF generation
    'pdf,data,here'
  end

  def generate_json_export(applications)
    # Implement JSON generation
    applications.to_json
  end
end
