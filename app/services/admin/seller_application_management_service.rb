# frozen_string_literal: true

module Admin
  # Enterprise-grade service for managing seller applications with comprehensive business logic
  class SellerApplicationManagementService
    include ServiceResultHelper

    # Custom exceptions for better error handling
    class ApplicationNotFound < StandardError; end
    class InvalidStatusTransition < StandardError; end
    class UserUpdateFailed < StandardError; end

    attr_reader :seller_application, :admin_user, :params

    # Initializes the service with required dependencies
    # @param seller_application [SellerApplication] The application to manage
    # @param admin_user [User] The admin performing the action
    # @param params [Hash] The parameters for the operation
    def initialize(seller_application, admin_user, params = {})
      @seller_application = seller_application
      @admin_user = admin_user
      @params = params
    end

    # Processes seller application status updates with full business logic
    # @return [ServiceResult] Result object with success/failure status and data
    def process_application_update
      validate_preconditions!
      ActiveRecord::Base.transaction do
        update_application_status
        handle_approval_logic if seller_application.approved?
        log_admin_action
        notify_stakeholders
      end

      success_result(seller_application, 'Seller application updated successfully')
    rescue ActiveRecord::RecordInvalid => e
      failure_result("Validation failed: #{e.message}")
    rescue InvalidStatusTransition => e
      failure_result("Invalid status transition: #{e.message}")
    rescue UserUpdateFailed => e
      failure_result("Failed to update user: #{e.message}")
    rescue StandardError => e
      failure_result("Unexpected error: #{e.message}")
    end

    # Retrieves paginated seller applications with optimized queries
    # @param page [Integer] Page number for pagination
    # @param per_page [Integer] Number of items per page
    # @param filters [Hash] Additional filters to apply
    # @return [ServiceResult] Result object with paginated applications
    def self.fetch_applications(page: 1, per_page: 25, filters: {})
      cache_key = "seller_applications_#{page}_#{per_page}_#{filters.hash}"

      # Cache for 5 minutes to improve performance
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        applications = optimize_query(filters)
        applications = applications.page(page).per(per_page)
        applications = applications.includes(:user, :reviews, :products)

        success_result(applications, 'Applications retrieved successfully')
      end
    rescue StandardError => e
      failure_result("Failed to fetch applications: #{e.message}")
    end

    private

    # Validates preconditions before processing
    def validate_preconditions!
      raise ApplicationNotFound unless seller_application.present?
      raise InvalidStatusTransition unless valid_status_transition?
    end

    # Updates the seller application with proper validation
    def update_application_status
      unless seller_application.update(seller_application_params)
        raise ActiveRecord::RecordInvalid.new(seller_application)
      end
    end

    # Handles business logic when application is approved
    def handle_approval_logic
      update_user_type_and_status
      create_approval_notification
      schedule_bond_requirement
    end

    # Updates user type and seller status atomically
    def update_user_type_and_status
      user = seller_application.user
      return if user.nil?

      unless user.update(user_type: :gem, seller_status: :awaiting_bond)
        raise UserUpdateFailed, user.errors.full_messages.join(', ')
      end
    end

    # Creates notification for approval
    def create_approval_notification
      Notification.create!(
        user: seller_application.user,
        title: 'Seller Application Approved',
        message: 'Congratulations! Your seller application has been approved.',
        notification_type: :seller_approval,
        metadata: {
          application_id: seller_application.id,
          approved_by: admin_user.id,
          approved_at: Time.current
        }
      )
    end

    # Schedules background job for bond requirement
    def schedule_bond_requirement
      SellerBondRequirementJob.perform_later(seller_application.user_id)
    end

    # Logs the admin action for audit trail
    def log_admin_action
      AdminActionLog.create!(
        admin_user: admin_user,
        action: 'update_seller_application',
        target_type: 'SellerApplication',
        target_id: seller_application.id,
        metadata: {
          old_status: seller_application.previous_changes['status']&.first,
          new_status: seller_application.status,
          feedback: params[:feedback],
          ip_address: admin_user.current_sign_in_ip,
          user_agent: admin_user.user_agent
        }
      )
    end

    # Sends notifications to relevant stakeholders
    def notify_stakeholders
      # Notify admin of successful update
      AdminNotificationService.notify_application_update(admin_user, seller_application)

      # Notify user of status change
      UserNotificationService.notify_application_status_change(seller_application.user, seller_application)
    end

    # Validates status transition rules
    def valid_status_transition?
      current_status = seller_application.status
      new_status = params[:status]

      # Define valid transitions
      valid_transitions = {
        'pending' => ['approved', 'rejected', 'under_review'],
        'under_review' => ['approved', 'rejected', 'pending'],
        'approved' => ['suspended'], # Approved can only be suspended
        'rejected' => ['pending'], # Rejected can be reconsidered
        'suspended' => ['approved', 'rejected'] # Suspended can be reactivated or rejected
      }

      valid_transitions[current_status.to_s]&.include?(new_status.to_s) || false
    end

    # Optimizes database query based on filters
    def self.optimize_query(filters)
      query = SellerApplication.all

      # Apply status filter if provided
      query = query.where(status: filters[:status]) if filters[:status].present?

      # Apply date range filters
      if filters[:date_from].present?
        query = query.where('created_at >= ?', filters[:date_from])
      end

      if filters[:date_to].present?
        query = query.where('created_at <= ?', filters[:date_to])
      end

      # Apply search filters
      if filters[:search].present?
        query = query.joins(:user)
                    .where('users.email ILIKE :search OR users.first_name ILIKE :search OR users.last_name ILIKE :search',
                          search: "%#{filters[:search]}%")
      end

      # Apply sorting
      sort_column = filters[:sort_by] || 'created_at'
      sort_direction = filters[:sort_direction] || 'desc'
      query = query.order("#{sort_column} #{sort_direction}")

      query
    end

    # Sanitizes and validates parameters
    def seller_application_params
      params.require(:seller_application).permit(:status, :feedback, :admin_notes)
    end
  end
end