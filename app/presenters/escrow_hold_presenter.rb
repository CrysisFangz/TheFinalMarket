class EscrowHoldPresenter
  def initialize(escrow_hold)
    @escrow_hold = escrow_hold
  end

  def as_json(options = {})
    {
      id: @escrow_hold.id,
      payment_account_id: @escrow_hold.payment_account_id,
      order_id: @escrow_hold.order_id,
      amount: @escrow_hold.amount,
      amount_cents: @escrow_hold.amount_cents,
      reason: @escrow_hold.reason,
      status: @escrow_hold.status,
      expires_at: @escrow_hold.expires_at,
      released_at: @escrow_hold.released_at,
      created_at: @escrow_hold.created_at,
      updated_at: @escrow_hold.updated_at,
      expiring_soon: @escrow_hold.expires_at <= 24.hours.from_now,
      days_until_expiry: (@escrow_hold.expires_at.to_date - Date.current).to_i
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end