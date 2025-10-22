# =============================================================================
# Confirm Transaction Interactor - Orchestrated Confirmation Workflow
# =============================================================================
# This interactor orchestrates the complex workflow for confirming XRP
# transactions, integrating verification, balance updates, notifications,
# and audit logging in a single, atomic operation.

class ConfirmTransactionInteractor
  include Interactor

  # Context requirements
  context_requires :transaction

  # Main orchestration method
  def call
    transaction = context.transaction

    # Step 1: Verify transaction consensus
    verification_result = verify_consensus(transaction)
    context.fail!(message: verification_result[:reason]) unless verification_result[:valid]

    # Step 2: Update transaction status
    update_transaction_status(transaction, verification_result)

    # Step 3: Execute post-confirmation actions
    execute_post_confirmation_actions(transaction)

    # Step 4: Update wallet balances
    update_wallet_balances(transaction)

    # Step 5: Send notifications
    send_notifications(transaction)

    # Step 6: Record audit trail
    record_audit_trail(transaction)
  end

  private

  # Verify transaction consensus across nodes
  def verify_consensus(transaction)
    TransactionConfirmationService.verify_consensus(transaction.transaction_hash)
  end

  # Update transaction status with verification data
  def update_transaction_status(transaction, verification_result)
    transaction.update!(
      status: :confirmed,
      confirmed_at: Time.current,
      confirmation_verifications: verification_result[:verifications]
    )
  end

  # Execute type-specific post-confirmation actions
  def execute_post_confirmation_actions(transaction)
    TransactionConfirmationService.execute_post_confirmation_actions(transaction)
  end

  # Update wallet balances atomically
  def update_wallet_balances(transaction)
    WalletBalanceService.update_balances(transaction)
  end

  # Send confirmation notifications
  def send_notifications(transaction)
    NotificationService.notify(
      recipient: transaction.user,
      action: :xrp_payment_confirmed,
      notifiable: transaction,
      data: {
        amount: transaction.amount_xrp,
        transaction_hash: transaction.transaction_hash,
        confirmations: transaction.confirmations
      }
    )
  end

  # Record audit trail
  def record_audit_trail(transaction)
    AuditTrail.record(
      entity_type: 'XrpTransaction',
      entity_id: transaction.id,
      action: 'transaction_confirmed',
      user: transaction.user,
      metadata: {
        amount_xrp: transaction.amount_xrp,
        transaction_hash: transaction.transaction_hash,
        confirmation_verifications: transaction.confirmation_verifications
      }
    )
  end
end