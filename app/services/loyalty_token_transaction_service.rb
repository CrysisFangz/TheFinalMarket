class LoyaltyTokenTransactionService
  attr_reader :loyalty_token

  def initialize(loyalty_token)
    @loyalty_token = loyalty_token
  end

  def earn(amount, reason, metadata = {})
    Rails.logger.info("Earning #{amount} tokens for LoyaltyToken ID: #{loyalty_token.id}, reason: #{reason}")
    loyalty_token.transaction do
      loyalty_token.increment!(:balance, amount)
      loyalty_token.increment!(:total_earned, amount)

      loyalty_token.token_transactions.create!(
        transaction_type: :earned,
        amount: amount,
        balance_after: loyalty_token.balance,
        reason: reason,
        metadata: metadata
      )
    end
    Rails.logger.info("Tokens earned successfully for LoyaltyToken ID: #{loyalty_token.id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error earning tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error earning tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  end

  def spend(amount, reason, metadata = {})
    Rails.logger.info("Spending #{amount} tokens for LoyaltyToken ID: #{loyalty_token.id}, reason: #{reason}")
    return false if loyalty_token.balance < amount

    loyalty_token.transaction do
      loyalty_token.decrement!(:balance, amount)
      loyalty_token.increment!(:total_spent, amount)

      loyalty_token.token_transactions.create!(
        transaction_type: :spent,
        amount: amount,
        balance_after: loyalty_token.balance,
        reason: reason,
        metadata: metadata
      )
    end
    Rails.logger.info("Tokens spent successfully for LoyaltyToken ID: #{loyalty_token.id}")
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error spending tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error spending tokens for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  end

  def transfer_to(recipient, amount, note = nil)
    Rails.logger.info("Transferring #{amount} tokens from LoyaltyToken ID: #{loyalty_token.id} to user ID: #{recipient.id}")
    return false if loyalty_token.balance < amount
    return false if recipient == loyalty_token.user

    loyalty_token.transaction do
      # Deduct from sender
      spend(amount, 'Transfer to user', { recipient_id: recipient.id, note: note })

      # Add to recipient
      recipient_token = recipient.loyalty_token || recipient.create_loyalty_token
      recipient_token.earn(amount, 'Transfer from user', { sender_id: loyalty_token.user.id, note: note })
    end
    Rails.logger.info("Tokens transferred successfully from LoyaltyToken ID: #{loyalty_token.id}")
    true
  rescue StandardError => e
    Rails.logger.error("Error transferring tokens from LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  end

  def redeem_for_discount(amount)
    Rails.logger.info("Redeeming #{amount} tokens for discount for LoyaltyToken ID: #{loyalty_token.id}")
    return false if loyalty_token.balance < amount

    discount_value = (amount * LoyaltyToken::TOKEN_TO_USD_RATE * 100).to_i # in cents

    spend(amount, 'Redeemed for discount', { discount_cents: discount_value })

    Rails.logger.info("Tokens redeemed for discount successfully for LoyaltyToken ID: #{loyalty_token.id}")
    discount_value
  rescue StandardError => e
    Rails.logger.error("Error redeeming tokens for discount for LoyaltyToken ID: #{loyalty_token.id} - #{e.message}")
    raise
  end
end