# frozen_string_literal: true

##
# Service for handling admin bond approval operations with comprehensive
# error handling, audit logging, and business rule validation.
#
# @version 1.0.0
# @author Kilo Code AI
class AdminBondApprovalService
  include ServiceResultHelper

  ##
  # Initialize the service with required dependencies
  #
  # @param admin [Admin] The admin performing the approval
  # @param bond [Bond] The bond to be approved
  def initialize(admin, bond)
    @admin = admin
    @bond = bond
  end

  ##
  # Execute the bond approval process
  #
  # @return [ServiceResult] Success/failure result with metadata
  def execute
    return failure_result('Bond is already active') if @bond.active?

    ActiveRecord::Base.transaction do
      approve_bond
      log_admin_action
      notify_stakeholders
    end

    success_result('Bond approved successfully')
  rescue ActiveRecord::RecordInvalid => e
    failure_result("Validation failed: #{e.message}")
  rescue => e
    Rails.logger.error("Admin bond approval failed: #{e.message}")
    failure_result('Failed to approve bond due to system error')
  end

  private

  ##
  # Approve the bond and update its status
  def approve_bond
    @bond.update!(
      status: :active,
      paid_at: Time.current,
      approved_by: @admin.id,
      approved_at: Time.current
    )

    # Create audit transaction record
    @bond.bond_transactions.create!(
      transaction_type: :admin_approval,
      amount: @bond.amount,
      metadata: {
        approved_by: @admin.id,
        admin_name: @admin.name,
        approval_method: 'admin_panel'
      }
    )
  end

  ##
  # Log the admin action for audit purposes
  def log_admin_action
    AdminActionLog.create!(
      admin: @admin,
      action: 'bond_approved',
      target_type: 'Bond',
      target_id: @bond.id,
      metadata: {
        bond_amount: @bond.amount.format,
        user_id: @bond.user_id,
        previous_status: @bond.status_before_last_save
      }
    )
  end

  ##
  # Notify relevant stakeholders about the approval
  def notify_stakeholders
    # Notify the user
    NotificationService.notify(
      user: @bond.user,
      title: 'Seller Bond Approved',
      body: "Your seller bond of #{@bond.amount.format} has been approved by an administrator.",
      category: :bond_update
    )

    # Notify other admins (optional - for high-value bonds)
    notify_other_admins if high_value_bond?
  end

  ##
  # Check if this is a high-value bond requiring additional oversight
  #
  # @return [Boolean] True if bond value exceeds threshold
  def high_value_bond?
    @bond.amount_cents > 100_000 # $1000 threshold
  end

  ##
  # Notify other administrators about high-value bond approval
  def notify_other_admins
    Admin.where.not(id: @admin.id).find_each do |admin|
      NotificationService.notify(
        user: admin,
        title: 'High-Value Bond Approved',
        body: "Admin #{@admin.name} approved a bond worth #{@bond.amount.format} for user #{@bond.user.email}",
        category: :admin_alert
      )
    end
  end
end