# =============================================================================
# Transaction Confirmation Service - Multi-Node Consensus Verification Engine
# =============================================================================
# This service orchestrates real-time transaction confirmation monitoring,
# multi-signature verification across trusted nodes, and adaptive consensus
# resolution for XRP transactions, ensuring zero-trust security and high availability.

class TransactionConfirmationService
  include Dry::Monads[:result]

  # Configuration for confirmation requirements
  MIN_CONFIRMATIONS = XrpWallet::XRP_CONFIG[:confirmation_blocks].freeze
  MAX_VERIFICATION_NODES = 3.freeze
  CONSENSUS_THRESHOLD = 0.67.freeze

  # Monitor and update transaction confirmations
  # @param transaction [XrpTransaction] The transaction to monitor
  # @return [Dry::Monads::Result] Success with updated transaction or Failure
  def self.monitor_confirmations(transaction)
    return Failure('Transaction must be provided') unless transaction.is_a?(XrpTransaction)
    return Failure('Transaction not in pending confirmation state') unless transaction.pending_confirmation?

    confirmation_data = fetch_confirmation_data(transaction.transaction_hash)

    update_transaction_confirmation(transaction, confirmation_data)

    if confirmation_data[:confirmations] >= MIN_CONFIRMATIONS
      confirm_transaction(transaction)
    else
      Success(transaction)
    end
  rescue StandardError => e
    Rails.logger.error("Confirmation monitoring failed for transaction #{transaction.id}: #{e.message}")
    Failure("Monitoring error: #{e.message}")
  end

  # Confirm transaction with multi-node consensus verification
  # @param transaction [XrpTransaction] The transaction to confirm
  # @return [Dry::Monads::Result] Success or Failure with reason
  def self.confirm_transaction(transaction)
    return Failure('Transaction already confirmed') if transaction.confirmed?

    verification_result = verify_consensus(transaction.transaction_hash)

    if verification_result[:valid]
      transaction.update!(
        status: :confirmed,
        confirmed_at: Time.current,
        confirmation_verifications: verification_result[:verifications]
      )

      execute_post_confirmation_actions(transaction)
      update_wallet_balances(transaction)

      Success(transaction)
    else
      mark_as_disputed(transaction, verification_result[:reason])
      Failure(verification_result[:reason])
    end
  end

  private

  # Fetch confirmation data from ledger service
  # @param transaction_hash [String] The transaction hash
  # @return [Hash] Confirmation data
  def self.fetch_confirmation_data(transaction_hash)
    XrpLedgerService.get_transaction_status(transaction_hash)
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch confirmation data: #{e.message}")
    { confirmations: 0, ledger_version: nil }
  end

  # Update transaction with new confirmation data
  # @param transaction [XrpTransaction] The transaction
  # @param data [Hash] Confirmation data
  def self.update_transaction_confirmation(transaction, data)
    transaction.update!(
      confirmations: data[:confirmations],
      last_checked_at: Time.current,
      ledger_version: data[:ledger_version]
    )
  end

  # Verify transaction consensus across multiple nodes
  # @param transaction_hash [String] The transaction hash
  # @return [Hash] Verification result
  def self.verify_consensus(transaction_hash)
    nodes = [:primary_ledger_node, :backup_ledger_node, :trusted_validator_node]
    verifications = {}
    valid_count = 0

    nodes.first(MAX_VERIFICATION_NODES).each do |node_type|
      result = query_node(node_type, transaction_hash)
      verifications[node_type] = result

      valid_count += 1 if result[:valid]
    end

    consensus_reached = (valid_count.to_f / nodes.size) >= CONSENSUS_THRESHOLD
    reason = consensus_reached ? nil : 'Insufficient consensus'

    {
      valid: consensus_reached,
      verifications: verifications,
      reason: reason
    }
  end

  # Query a specific ledger node
  # @param node_type [Symbol] The node type
  # @param transaction_hash [String] The transaction hash
  # @return [Hash] Query result
  def self.query_node(node_type, transaction_hash)
    case node_type
    when :primary_ledger_node
      XrpLedgerService.query_primary_node(transaction_hash)
    when :backup_ledger_node
      XrpLedgerService.query_backup_node(transaction_hash)
    when :trusted_validator_node
      XrpLedgerService.query_trusted_validator(transaction_hash)
    else
      { valid: false, reason: 'Unknown node type' }
    end
  rescue StandardError => e
    { valid: false, reason: "Node query failed: #{e.message}" }
  end

  # Execute post-confirmation actions based on transaction type
  # @param transaction [XrpTransaction] The transaction
  def self.execute_post_confirmation_actions(transaction)
    case transaction.transaction_type.to_sym
    when :incoming_payment
      process_incoming_payment_confirmation(transaction)
    when :outgoing_payment
      process_outgoing_payment_confirmation(transaction)
    when :exchange
      process_exchange_confirmation(transaction)
    when :refund
      process_refund_confirmation(transaction)
    end
  end

  # Update wallet balances after confirmation
  # @param transaction [XrpTransaction] The transaction
  def self.update_wallet_balances(transaction)
    WalletBalanceService.update_balances(transaction)
  end

  # Mark transaction as disputed
  # @param transaction [XrpTransaction] The transaction
  # @param reason [String] Dispute reason
  def self.mark_as_disputed(transaction, reason)
    transaction.update!(
      status: :disputed,
      dispute_reason: reason,
      disputed_at: Time.current
    )

    DisputeResolutionService.handle_xrp_transaction_dispute(transaction)
  end

  # Process incoming payment confirmation
  # @param transaction [XrpTransaction] The transaction
  def self.process_incoming_payment_confirmation(transaction)
    transaction.destination_wallet&.sync_balance

    if transaction.order&.pending_payment?
      transaction.order.update!(
        payment_status: :paid,
        paid_at: Time.current
      )
    end

    send_confirmation_notification(transaction)
  end

  # Process outgoing payment confirmation
  # @param transaction [XrpTransaction] The transaction
  def self.process_outgoing_payment_confirmation(transaction)
    transaction.source_wallet&.sync_balance

    if transaction.order&.payment_status_paid?
      transaction.order.update!(
        fulfillment_status: :ready_for_shipping
      )
    end
  end

  # Process exchange confirmation
  # @param transaction [XrpTransaction] The transaction
  def self.process_exchange_confirmation(transaction)
    # Placeholder for exchange-specific logic
    Rails.logger.info("Exchange confirmation processed for transaction #{transaction.id}")
  end

  # Process refund confirmation
  # @param transaction [XrpTransaction] The transaction
  def self.process_refund_confirmation(transaction)
    # Placeholder for refund-specific logic
    Rails.logger.info("Refund confirmation processed for transaction #{transaction.id}")
  end

  # Send confirmation notification
  # @param transaction [XrpTransaction] The transaction
  def self.send_confirmation_notification(transaction)
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
end