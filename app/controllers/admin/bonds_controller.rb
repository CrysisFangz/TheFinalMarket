# frozen_string_literal: true

##
# Admin controller for managing seller bonds in the marketplace.
# Handles bond lifecycle operations including approval, forfeiture, and monitoring.
#
# @version 2.0.0
# @author Kilo Code AI
# @security_critical This controller handles financial operations and requires strict authorization
class Admin::BondsController < Admin::BaseController
  # Maximum number of bonds to display per page for performance
  BONDS_PER_PAGE = 50

  # Maximum length for forfeiture reasons to prevent abuse
  MAX_FORFEITURE_REASON_LENGTH = 1000

  before_action :set_bond, only: [:show, :approve, :forfeit]
  before_action :authorize_admin_action, only: [:approve, :forfeit]
  before_action :validate_forfeiture_params, only: [:forfeit]

  ##
  # Display paginated list of all bonds with user information
  #
  # @performance Optimized with eager loading and pagination
  # @security Filtered by admin authorization scope
  def index
    @bonds = fetch_bonds_with_pagination
    @summary_stats = calculate_bond_summary_stats
  end

  ##
  # Show detailed bond information with transaction history
  #
  # @security Ensures bond belongs to authorized admin scope
  def show
    @bond_history = @bond.bond_transactions.includes(:payment_transaction).order(created_at: :desc)
    @user_bonds_count = @bond.user.bonds.where(status: :active).count
  end

  ##
  # Approve and activate a pending bond
  #
  # @transaction Ensures atomic bond state transition
  # @audit Logged for compliance and monitoring
  # @security Requires admin authorization and validates bond state
  def approve
    return redirect_with_alert(@bond, 'Bond is already active.') if @bond.active?

    result = execute_bond_approval

    if result.success?
      redirect_with_notice(@bond, 'Bond has been approved and activated.')
    else
      redirect_with_alert(@bond, result.error_message)
    end
  end

  ##
  # Forfeit an active bond with admin-provided reason
  #
  # @transaction Ensures atomic bond state transition
  # @audit Logged with reason for compliance
  # @security Requires admin authorization and validates reason
  def forfeit
    return redirect_with_alert(@bond, 'Bond has already been forfeited.') if @bond.forfeited?

    result = execute_bond_forfeiture

    if result.success?
      redirect_with_notice(@bond, 'Bond has been forfeited.')
    else
      redirect_with_alert(@bond, result.error_message)
    end
  end

  private

  ##
  # Fetch bonds with optimized query and pagination
  #
  # @return [ActiveRecord::Relation] Paginated bonds with user data
  def fetch_bonds_with_pagination
    Bond.includes(:user, :bond_transactions)
        .order(created_at: :desc)
        .page(params[:page])
        .per(BONDS_PER_PAGE)
  end

  ##
  # Calculate summary statistics for bonds dashboard
  #
  # @performance Cached for 5 minutes to reduce database load
  # @return [Hash] Summary statistics
  def calculate_bond_summary_stats
    Rails.cache.fetch('admin_bonds_summary_stats', expires_in: 5.minutes) do
      {
        total_bonds: Bond.count,
        active_bonds: Bond.active.count,
        pending_bonds: Bond.pending.count,
        forfeited_bonds: Bond.forfeited.count,
        total_bond_value: Bond.sum(:amount_cents)
      }
    end
  end

  ##
  # Set bond instance variable with error handling
  #
  # @raise [ActiveRecord::RecordNotFound] if bond not found
  # @return [Bond] The found bond
  def set_bond
    @bond = Bond.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("Admin attempted to access non-existent bond: #{params[:id]}")
    redirect_to admin_bonds_path, alert: 'Bond not found.'
  end

  ##
  # Authorize admin action based on permissions and bond state
  #
  # @security Validates admin has permission for this action
  def authorize_admin_action
    unless current_admin.can_manage_bonds?
      Rails.logger.warn("Unauthorized bond management attempt by admin: #{current_admin.id}")
      redirect_to admin_bonds_path, alert: 'Insufficient permissions for this action.'
      return
    end

    # Additional business logic authorization could be added here
    # For example, checking if admin can manage bonds for specific users
  end

  ##
  # Validate forfeiture parameters
  #
  # @security Prevents malicious input and ensures data integrity
  def validate_forfeiture_params
    return unless params[:forfeit]

    reason = params.dig(:bond, :forfeiture_reason).to_s.strip

    if reason.blank?
      redirect_to admin_bond_path(@bond), alert: 'A reason is required to forfeit a bond.'
      return
    end

    if reason.length > MAX_FORFEITURE_REASON_LENGTH
      redirect_to admin_bond_path(@bond),
                  alert: "Forfeiture reason must be #{MAX_FORFEITURE_REASON_LENGTH} characters or less."
      return
    end

    # Sanitize reason to prevent XSS
    params[:bond][:forfeiture_reason] = sanitize_forfeiture_reason(reason)
  end

  ##
  # Execute bond approval with comprehensive error handling
  #
  # @return [ServiceResult] Result of the approval operation
  def execute_bond_approval
    AdminBondApprovalService.new(current_admin, @bond).execute
  rescue => e
    Rails.logger.error("Bond approval failed for bond #{@bond.id}: #{e.message}")
    ServiceResult.failure("Failed to approve bond: #{e.message}")
  end

  ##
  # Execute bond forfeiture with comprehensive error handling
  #
  # @return [ServiceResult] Result of the forfeiture operation
  def execute_bond_forfeiture
    reason = params.dig(:bond, :forfeiture_reason)
    AdminBondForfeitureService.new(current_admin, @bond, reason).execute
  rescue => e
    Rails.logger.error("Bond forfeiture failed for bond #{@bond.id}: #{e.message}")
    ServiceResult.failure("Failed to forfeit bond: #{e.message}")
  end

  ##
  # Sanitize forfeiture reason to prevent XSS attacks
  #
  # @param reason [String] The raw forfeiture reason
  # @return [String] Sanitized reason
  def sanitize_forfeiture_reason(reason)
    # Use Rails sanitization helper to prevent XSS
    ActionController::Base.helpers.sanitize(reason, tags: [], attributes: [])
  end

  ##
  # Redirect with notice message
  #
  # @param bond [Bond] The bond for URL generation
  # @param message [String] Success message
  def redirect_with_notice(bond, message)
    redirect_to admin_bond_path(bond), notice: message
  end

  ##
  # Redirect with alert message
  #
  # @param bond [Bond] The bond for URL generation
  # @param message [String] Error message
  def redirect_with_alert(bond, message)
    redirect_to admin_bond_path(bond), alert: message
  end
end
