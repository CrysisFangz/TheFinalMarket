# frozen_string_literal: true

##
# Service for handling admin bond forfeiture operations with comprehensive
# error handling, audit logging, and business rule validation.
#
# @version 1.0.0
# @author Kilo Code AI
class AdminBondForfeitureService
  include ServiceResultHelper

  ##
  # Initialize the service with required dependencies
  #
  # @param admin [Admin] The admin performing the forfeiture
  # @param bond [Bond] The bond to be forfeited
  # @param reason [String] The reason for forfeiture
  def initialize(admin, bond, reason)
    @admin = admin
    @bond = bond
    @reason = reason
  end

  ##
  # Execute the bond forfeiture process
  #
  # @return [ServiceResult] Success/failure result with metadata
  def execute
    return failure_result('Bond has already been forfeited') if @bond.forfeited?
    return failure_result('Bond must be active to be forfeited') unless @bond.active?

    ActiveRecord::Base.transaction do
      forfeit_bond
      log_admin_action
      notify_stakeholders
      handle_post_forfeiture_actions
    end

    success_result('Bond forfeited successfully')
  rescue ActiveRecord::RecordInvalid => e
    failure_result("Validation failed: #{e.message}")
  rescue => e
    Rails.logger.error("Admin bond forfeiture failed: #{e.message}")
    failure_result('Failed to forfeit bond due to system error')
  end

  private

  ##
  # Forfeit the bond and update its status
  def forfeit_bond
    @bond.update!(
      status: :forfeited,
      forfeited_at: Time.current,
      forfeiture_reason: @reason,
      forfeited_by: @admin.id
    )

    # Create audit transaction record
    @bond.bond_transactions.create!(
      transaction_type: :admin_forfeiture,
      amount: @bond.amount,
      metadata: {
        forfeited_by: @admin.id,
        admin_name: @admin.name,
        reason: @reason,
        forfeiture_method: 'admin_panel'
      }
    )
  end

  ##
  # Log the admin action for audit purposes
  def log_admin_action
    AdminActionLog.create!(
      admin: @admin,
      action: 'bond_forfeited',
      target_type: 'Bond',
      target_id: @bond.id,
      metadata: {
        bond_amount: @bond.amount.format,
        user_id: @bond.user_id,
        forfeiture_reason: @reason,
        previous_status: @bond.status_before_last_save
      }
    )
  end

  ##
  # Notify relevant stakeholders about the forfeiture
  def notify_stakeholders
    # Notify the user about forfeiture
    NotificationService.notify(
      user: @bond.user,
      title: 'Seller Bond Forfeited',
      body: "Your seller bond has been forfeited by an administrator. Reason: #{@reason}",
      category: :account_warning
    )

    # Notify other admins about the forfeiture
    notify_other_admins
  end

  ##
  # Notify other administrators about the forfeiture
  def notify_other_admins
    Admin.where.not(id: @admin.id).find_each do |admin|
      NotificationService.notify(
        user: admin,
        title: 'Bond Forfeited',
        body: "Admin #{@admin.name} forfeited a bond worth #{@bond.amount.format} for user #{@bond.user.email}. Reason: #{@reason}",
        category: :admin_alert
      )
    end
  end

  ##
  # Handle any post-forfeiture business logic
  def handle_post_forfeiture_actions
    # Check if user should be suspended or have other restrictions applied
    check_user_restrictions

    # Update user's reputation score
    update_user_reputation

    # Check for fraud patterns
    check_fraud_patterns
  end

  ##
  # Check if user should face additional restrictions after bond forfeiture
  def check_user_restrictions
    forfeiture_count = @bond.user.bonds.forfeited.count

    if forfeiture_count >= 3
      UserRestrictionService.new(@bond.user).apply_bond_forfeiture_restrictions
    end
  end

  ##
  # Update user's reputation score after bond forfeiture
  def update_user_reputation
    ReputationService.new(@bond.user).record_bond_forfeiture(@bond.amount)
  end

  ##
  # Check for potential fraud patterns in bond forfeitures
  def check_fraud_patterns
    FraudDetectionService.new(@bond.user).analyze_bond_forfeiture_pattern
  end
end