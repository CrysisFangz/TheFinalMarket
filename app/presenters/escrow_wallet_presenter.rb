class EscrowWalletPresenter
  def initialize(escrow_wallet)
    @escrow_wallet = escrow_wallet
  end

  def as_json(options = {})
    {
      id: @escrow_wallet.id,
      user_id: @escrow_wallet.user_id,
      balance: @escrow_wallet.balance,
      held_balance: @escrow_wallet.held_balance,
      total_balance: @escrow_wallet.total_balance,
      created_at: @escrow_wallet.created_at,
      updated_at: @escrow_wallet.updated_at,
      transactions_count: @escrow_wallet.escrow_transactions.count,
      held_orders_count: @escrow_wallet.held_orders.count,
      available_balance: @escrow_wallet.available_balance
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end