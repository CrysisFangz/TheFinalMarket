class SellerPaymentService
  def self.call(seller_account, transaction)
    new(seller_account, transaction).call
  end

  def initialize(seller_account, transaction)
    @seller_account = seller_account
    @transaction = transaction
  end

  def call
    return Result.failure('Transaction not in held status') unless @transaction.status == 'held'

    accept_payment
    Result.success('Payment accepted successfully')
  rescue StandardError => e
    Result.failure("Payment acceptance failed: #{e.message}")
  end

  private

  def accept_payment
    @seller_account.with_lock do
      @seller_account.available_balance += @transaction.amount
      @seller_account.save!
      @transaction.update!(status: 'completed')
    end
  end
end