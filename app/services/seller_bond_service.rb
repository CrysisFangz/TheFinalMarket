class SellerBondService
  def self.call(seller_account)
    new(seller_account).call
  end

  def initialize(seller_account)
    @seller_account = seller_account
  end

  def call
    return Result.failure('No held balance to release') unless seller_account.held_balance.positive?

    release_bond
    Result.success('Bond released successfully')
  rescue StandardError => e
    Result.failure("Bond release failed: #{e.message}")
  end

  private

  attr_reader :seller_account

  def release_bond
    seller_account.transaction do
      seller_account.release_funds(seller_account.held_balance, "Bond release")
      seller_account.update!(status: :closed)
    end
  end
end