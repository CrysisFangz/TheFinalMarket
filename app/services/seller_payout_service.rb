class SellerPayoutService
  PAYOUT_COOLDOWN_PERIOD = 7.days

  def self.call(seller_account)
    new(seller_account).call
  end

  def initialize(seller_account)
    @seller_account = seller_account
  end

  def call
    return Result.failure('Account not eligible for payout') unless eligible?

    process_payout
    Result.success('Payout processed successfully')
  rescue StandardError => e
    Result.failure("Payout failed: #{e.message}")
  end

  private

  attr_reader :seller_account

  def eligible?
    seller_account.active? &&
      seller_account.available_balance.positive? &&
      (seller_account.last_payout_at.nil? || seller_account.last_payout_at < PAYOUT_COOLDOWN_PERIOD.ago)
  end

  def process_payout
    amount = seller_account.available_balance

    seller_account.transaction do
      payout = seller_account.payouts.create!(
        amount: amount,
        status: :pending,
        stripe_payout_id: nil
      )

      PayoutJob.perform_later(payout)
      seller_account.update!(last_payout_at: Time.current)
    end
  end
end

# Simple Result class for success/failure
class Result
  def self.success(message)
    new(true, message)
  end

  def self.failure(message)
    new(false, message)
  end

  attr_reader :success, :message

  def initialize(success, message)
    @success = success
    @message = message
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end