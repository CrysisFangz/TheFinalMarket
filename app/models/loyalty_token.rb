class LoyaltyToken < ApplicationRecord
  belongs_to :user
  
  has_many :token_transactions, dependent: :destroy
  has_many :token_rewards, dependent: :destroy
  
  validates :user, presence: true
  validates :balance, numericality: { greater_than_or_equal_to: 0 }
  
  # Token symbol
  TOKEN_SYMBOL = 'FMT' # Final Market Token
  TOKEN_NAME = 'Final Market Loyalty Token'
  
  # Conversion rates
  USD_TO_TOKEN_RATE = 10 # 1 USD = 10 FMT
  TOKEN_TO_USD_RATE = 0.10 # 1 FMT = $0.10
  
  # Earn tokens
  def earn(amount, reason, metadata = {})
    transaction do
      increment!(:balance, amount)
      increment!(:total_earned, amount)
      
      token_transactions.create!(
        transaction_type: :earned,
        amount: amount,
        balance_after: balance,
        reason: reason,
        metadata: metadata
      )
    end
  end
  
  # Spend tokens
  def spend(amount, reason, metadata = {})
    return false if balance < amount
    
    transaction do
      decrement!(:balance, amount)
      increment!(:total_spent, amount)
      
      token_transactions.create!(
        transaction_type: :spent,
        amount: amount,
        balance_after: balance,
        reason: reason,
        metadata: metadata
      )
    end
  end
  
  # Transfer tokens to another user
  def transfer_to(recipient, amount, note = nil)
    return false if balance < amount
    return false if recipient == user
    
    transaction do
      # Deduct from sender
      spend(amount, 'Transfer to user', { recipient_id: recipient.id, note: note })
      
      # Add to recipient
      recipient_token = recipient.loyalty_token || recipient.create_loyalty_token
      recipient_token.earn(amount, 'Transfer from user', { sender_id: user.id, note: note })
    end
  end
  
  # Redeem tokens for discount
  def redeem_for_discount(amount)
    return false if balance < amount
    
    discount_value = (amount * TOKEN_TO_USD_RATE * 100).to_i # in cents
    
    spend(amount, 'Redeemed for discount', { discount_cents: discount_value })
    
    discount_value
  end
  
  # Convert USD to tokens
  def self.usd_to_tokens(usd_amount)
    (usd_amount * USD_TO_TOKEN_RATE).to_i
  end
  
  # Convert tokens to USD
  def self.tokens_to_usd(token_amount)
    (token_amount * TOKEN_TO_USD_RATE).round(2)
  end
  
  # Stake tokens
  def stake(amount, duration_days)
    return false if balance < amount
    
    # Calculate rewards (APY based on duration)
    apy = calculate_staking_apy(duration_days)
    reward_amount = (amount * apy / 365.0 * duration_days).to_i
    
    transaction do
      decrement!(:balance, amount)
      increment!(:staked_balance, amount)
      
      token_rewards.create!(
        reward_type: :staking,
        amount_staked: amount,
        reward_amount: reward_amount,
        apy: apy,
        starts_at: Time.current,
        ends_at: duration_days.days.from_now,
        status: :active
      )
    end
  end
  
  # Unstake tokens
  def unstake(reward_id)
    reward = token_rewards.find(reward_id)
    return false unless reward.active?
    
    transaction do
      # Return staked amount
      increment!(:balance, reward.amount_staked)
      decrement!(:staked_balance, reward.amount_staked)
      
      # Pay rewards if matured
      if reward.ends_at <= Time.current
        increment!(:balance, reward.reward_amount)
        reward.update!(status: :completed, claimed_at: Time.current)
      else
        # Early withdrawal penalty
        penalty = (reward.reward_amount * 0.5).to_i
        increment!(:balance, penalty)
        reward.update!(status: :early_withdrawal, claimed_at: Time.current)
      end
    end
  end
  
  # Get token value in USD
  def value_usd
    self.class.tokens_to_usd(balance)
  end
  
  # Get staking rewards
  def pending_rewards
    token_rewards.active.sum(:reward_amount)
  end
  
  # Get transaction history
  def transaction_history(limit = 50)
    token_transactions.order(created_at: :desc).limit(limit)
  end
  
  # Export to wallet
  def export_to_wallet(wallet_address)
    # This would transfer tokens to external Web3 wallet
    # For now, just record the export
    
    token_transactions.create!(
      transaction_type: :exported,
      amount: balance,
      balance_after: 0,
      reason: 'Exported to Web3 wallet',
      metadata: { wallet_address: wallet_address }
    )
    
    update!(balance: 0, exported_to_wallet: wallet_address)
  end
  
  private
  
  def calculate_staking_apy(duration_days)
    # Higher APY for longer staking periods
    case duration_days
    when 0..30
      5.0 # 5% APY
    when 31..90
      10.0 # 10% APY
    when 91..180
      15.0 # 15% APY
    when 181..365
      20.0 # 20% APY
    else
      25.0 # 25% APY for 1+ year
    end
  end
end

