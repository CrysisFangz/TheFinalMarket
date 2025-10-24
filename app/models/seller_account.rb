 app/models/seller_account.rb
class SellerAccount < PaymentAccount
  PAYOUT_COOLDOWN_PERIOD = 7.days
  STRIPE_ACCOUNT_TYPE = 'connect'.freeze
  PENDING_STATUS = 'pending'.freeze
  COMPLETED_STATUS = 'completed'.freeze
  CLOSED_STATUS = :closed

  has_many :received_transactions, class_name: 'PaymentTransaction', foreign_key: 'target_account_id'
  has_many :payouts, dependent: :restrict_with_error

  include SquareAccount

  validates :business_email, presence: true, email: true, if: :active?
  validates :merchant_name, presence: true, if: :active?

  def eligible_for_payout?
    active? &&
      available_balance.positive? &&
      (last_payout_at.nil? || last_payout_at < PAYOUT_COOLDOWN_PERIOD.ago)
  end

  def process_payout
    result = SellerPayoutService.call(self)
    result.success?
  end

  def release_bond
    result = SellerBondService.call(self)
    result.success?
  end

  def accept_payment(transaction)
    result = SellerPaymentService.call(self, transaction)
    result.success?
  end

  private

  def stripe_account_type
    STRIPE_ACCOUNT_TYPE
  end
end