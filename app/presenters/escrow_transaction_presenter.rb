class EscrowTransactionPresenter
  def initialize(escrow_transaction)
    @escrow_transaction = escrow_transaction
  end

  def as_json(options = {})
    {
      id: @escrow_transaction.id,
      escrow_wallet_id: @escrow_transaction.escrow_wallet_id,
      order_id: @escrow_transaction.order_id,
      sender_id: @escrow_transaction.sender_id,
      receiver_id: @escrow_transaction.receiver_id,
      amount: @escrow_transaction.amount,
      transaction_type: @escrow_transaction.transaction_type,
      status: @escrow_transaction.status,
      needs_admin_approval: @escrow_transaction.needs_admin_approval?,
      admin_approved_at: @escrow_transaction.admin_approved_at,
      scheduled_release_at: @escrow_transaction.scheduled_release_at,
      refunded_amount: @escrow_transaction.refunded_amount,
      created_at: @escrow_transaction.created_at,
      updated_at: @escrow_transaction.updated_at,
      can_release_funds: @escrow_transaction.can_release_funds?(options[:admin_approved]),
      can_refund: @escrow_transaction.can_refund?(options[:admin_approved]),
      escrow_wallet_balance: @escrow_transaction.escrow_wallet.balance
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end