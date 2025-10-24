class EscrowManagementService
  def self.release!(escrow_hold)
    return false unless escrow_hold.active?

    escrow_hold.transaction do
      escrow_hold.update!(status: :released, released_at: Time.current)
      escrow_hold.payment_account.release_funds(escrow_hold.amount, escrow_hold.reason)
    end
    true
  end

  def self.expire!(escrow_hold)
    return false unless escrow_hold.active?
    return false unless escrow_hold.expires_at <= Time.current

    escrow_hold.transaction do
      escrow_hold.update!(status: :expired)
      escrow_hold.payment_account.release_funds(escrow_hold.amount, "Expired: #{escrow_hold.reason}")
    end
    true
  end

  def self.set_expiry(escrow_hold)
    escrow_hold.expires_at ||= case escrow_hold.reason
    when /bond/i
      30.days.from_now
    else
      7.days.from_now
    end
  end

  def self.schedule_expiry_check(escrow_hold)
    CheckEscrowExpiryJob.set(wait_until: escrow_hold.expires_at).perform_later(escrow_hold)
  end
end