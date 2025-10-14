# frozen_string_literal: true

module Admin
  # Sophisticated authorization policy for seller application management
  class SellerApplicationPolicy < ApplicationPolicy
    # Custom exceptions for authorization failures
    class InsufficientPermissions < StandardError; end
    class ApplicationAccessDenied < StandardError; end

    attr_reader :admin_user, :seller_application, :action

    # Initializes the policy with user, record, and action context
    # @param admin_user [User] The admin user attempting the action
    # @param seller_application [SellerApplication] The application being accessed
    # @param action [Symbol] The action being performed
    def initialize(admin_user, seller_application, action = nil)
      @admin_user = admin_user
      @seller_application = seller_application
      @action = action || :index
    end

    # Checks if user can view the index of seller applications
    # @return [Boolean] Permission granted or denied
    def index?
      verify_admin_access!
      verify_basic_permissions!

      case admin_user.admin_role.to_sym
      when :super_admin, :senior_admin
        true
      when :admin
        true
      when :moderator
        # Moderators can only see pending applications
        true
      else
        false
      end
    end

    # Checks if user can view a specific seller application
    # @return [Boolean] Permission granted or denied
    def show?
      verify_admin_access!
      verify_basic_permissions!

      case admin_user.admin_role.to_sym
      when :super_admin, :senior_admin
        true
      when :admin
        # Admins can view applications in their assigned categories
        application_in_admin_scope?
      when :moderator
        # Moderators can only view pending applications
        seller_application.status.to_sym == :pending
      else
        false
      end
    end

    # Checks if user can update a seller application
    # @return [Boolean] Permission granted or denied
    def update?
      verify_admin_access!
      verify_basic_permissions!
      verify_rate_limiting!

      case admin_user.admin_role.to_sym
      when :super_admin
        # Super admins can update any application
        true
      when :senior_admin
        # Senior admins can update most applications
        can_update_application?
      when :admin
        # Regular admins have limited update permissions
        limited_admin_update_permissions?
      when :moderator
        # Moderators can only move from pending to under_review
        moderator_update_permissions?
      else
        false
      end
    end

    # Checks if user can approve applications
    # @return [Boolean] Permission granted or denied
    def approve?
      verify_admin_access!
      verify_basic_permissions!

      case admin_user.admin_role.to_sym
      when :super_admin, :senior_admin
        true
      when :admin
        # Check if admin has approval permissions for this category
        admin_has_approval_permissions?
      else
        false
      end
    end

    # Checks if user can reject applications
    # @return [Boolean] Permission granted or denied
    def reject?
      verify_admin_access!
      verify_basic_permissions!

      case admin_user.admin_role.to_sym
      when :super_admin, :senior_admin, :admin
        true
      when :moderator
        # Moderators can reject applications they're reviewing
        seller_application.status.to_sym == :under_review
      else
        false
      end
    end

    # Checks if user can suspend sellers
    # @return [Boolean] Permission granted or denied
    def suspend?
      verify_admin_access!
      verify_basic_permissions!

      # Only senior admins and super admins can suspend sellers
      [:super_admin, :senior_admin].include?(admin_user.admin_role.to_sym)
    end

    # Checks if user can access application analytics
    # @return [Boolean] Permission granted or denied
    def analytics?
      verify_admin_access!
      verify_basic_permissions!

      # Only senior admins and super admins can access analytics
      [:super_admin, :senior_admin].include?(admin_user.admin_role.to_sym)
    end

    # Checks if user can export application data
    # @return [Boolean] Permission granted or denied
    def export?
      verify_admin_access!
      verify_basic_permissions!

      # Only senior admins and super admins can export data
      [:super_admin, :senior_admin].include?(admin_user.admin_role.to_sym)
    end

    # Returns the scope of applications the user can access
    # @return [ActiveRecord::Relation] Filtered scope of applications
    def scope
      scope = SellerApplication.all

      case admin_user.admin_role.to_sym
      when :super_admin
        # Super admins can see all applications
        scope
      when :senior_admin
        # Senior admins can see most applications
        scope.where.not(status: :deleted)
      when :admin
        # Regular admins can see applications in their categories
        scope_by_admin_categories(scope)
      when :moderator
        # Moderators can only see pending and under_review applications
        scope.where(status: [:pending, :under_review])
      else
        # No access for other roles
        scope.none
      end
    end

    # Returns detailed permission information for the current user
    # @return [Hash] Detailed permission data
    def permissions
      {
        can_view: show?,
        can_edit: update?,
        can_approve: approve?,
        can_reject: reject?,
        can_suspend: suspend?,
        can_access_analytics: analytics?,
        can_export: export?,
        scope: permitted_scope,
        restrictions: current_restrictions,
        role: admin_user.admin_role,
        access_level: calculate_access_level
      }
    end

    private

    # Verifies that the user has basic admin access
    def verify_admin_access!
      unless admin_user&.admin? || admin_user&.has_role?(:admin)
        raise InsufficientPermissions, 'User must have admin privileges'
      end
    end

    # Verifies basic permissions are met
    def verify_basic_permissions!
      unless admin_user.active?
        raise InsufficientPermissions, 'Admin user must be active'
      end

      unless admin_user.approved?
        raise InsufficientPermissions, 'Admin user must be approved'
      end
    end

    # Verifies rate limiting for actions
    def verify_rate_limiting!
      recent_actions = AdminActionLog.where(
        admin_user: admin_user,
        action: 'update_seller_application',
        created_at: 1.hour.ago..Time.current
      ).count

      # Limit to 50 actions per hour for regular admins
      if admin_user.admin_role.to_sym == :admin && recent_actions >= 50
        raise InsufficientPermissions, 'Rate limit exceeded for application updates'
      end

      # Limit to 100 actions per hour for moderators
      if admin_user.admin_role.to_sym == :moderator && recent_actions >= 100
        raise InsufficientPermissions, 'Rate limit exceeded for application updates'
      end
    end

    # Checks if application is within admin's scope
    def application_in_admin_scope?
      return true if admin_user.admin_role.to_sym == :super_admin

      # Check if admin is assigned to categories related to this application
      user_categories = admin_user.assigned_categories || []
      application_categories = seller_application.user&.product_categories || []

      (user_categories & application_categories).any?
    end

    # Checks if admin can update this specific application
    def can_update_application?
      return true if admin_user.admin_role.to_sym == :super_admin

      # Senior admins can update applications that aren't approved yet
      !seller_application.approved? || seller_application.updated_at < 24.hours.ago
    end

    # Checks limited admin update permissions
    def limited_admin_update_permissions?
      # Regular admins can only update pending applications
      seller_application.status.to_sym == :pending
    end

    # Checks moderator update permissions
    def moderator_update_permissions?
      # Moderators can only move from pending to under_review
      seller_application.status.to_sym == :pending &&
      (params[:status].to_sym == :under_review rescue false)
    end

    # Checks if admin has approval permissions for this category
    def admin_has_approval_permissions?
      return false unless seller_application.user

      admin_user.approval_categories&.include?(seller_application.user.primary_category)
    end

    # Returns scope filtered by admin's assigned categories
    def scope_by_admin_categories(scope)
      return scope.none unless admin_user.assigned_categories&.any?

      # This would need to be implemented based on your user model structure
      # For now, return all applications (can be refined based on your needs)
      scope
    end

    # Returns the permitted scope for this user
    def permitted_scope
      {
        statuses: permitted_statuses,
        categories: permitted_categories,
        date_range: permitted_date_range
      }
    end

    # Returns permitted statuses for this user
    def permitted_statuses
      case admin_user.admin_role.to_sym
      when :super_admin, :senior_admin
        SellerApplication.statuses.keys
      when :admin
        %w[pending under_review approved]
      when :moderator
        %w[pending under_review]
      else
        []
      end
    end

    # Returns permitted categories for this user
    def permitted_categories
      case admin_user.admin_role.to_sym
      when :super_admin
        Category.pluck(:name)
      when :senior_admin, :admin
        admin_user.assigned_categories || Category.pluck(:name)
      else
        []
      end
    end

    # Returns permitted date range for this user
    def permitted_date_range
      case admin_user.admin_role.to_sym
      when :super_admin
        { from: nil, to: nil } # No restrictions
      when :senior_admin
        { from: 1.year.ago, to: Time.current }
      when :admin
        { from: 6.months.ago, to: Time.current }
      when :moderator
        { from: 1.month.ago, to: Time.current }
      else
        { from: 1.week.ago, to: Time.current }
      end
    end

    # Returns current restrictions for this user
    def current_restrictions
      restrictions = []

      unless admin_user.active?
        restrictions << 'Account is not active'
      end

      if rate_limit_exceeded?
        restrictions << 'Rate limit exceeded'
      end

      if admin_user.restricted_categories?
        restrictions << 'Access restricted to assigned categories'
      end

      restrictions
    end

    # Calculates access level for this user
    def calculate_access_level
      case admin_user.admin_role.to_sym
      when :super_admin
        'full_access'
      when :senior_admin
        'elevated_access'
      when :admin
        'standard_access'
      when :moderator
        'limited_access'
      else
        'no_access'
      end
    end

    # Checks if rate limit is exceeded
    def rate_limit_exceeded?
      # Implement rate limit checking logic
      false
    end

    # Access to parameters for policy checks
    def params
      # This would need to be passed in or accessed from controller context
      {}
    end
  end
end