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
  
  # Delegated to LoyaltyTokenTransactionService
  def earn(amount, reason, metadata = {})
    @transaction_service ||= LoyaltyTokenTransactionService.new(self)
    @transaction_service.earn(amount, reason, metadata)
  end
  
  # Delegated to LoyaltyTokenTransactionService
  def spend(amount, reason, metadata = {})
    @transaction_service ||= LoyaltyTokenTransactionService.new(self)
    @transaction_service.spend(amount, reason, metadata)
  end
  
  # Delegated to LoyaltyTokenTransactionService
  def transfer_to(recipient, amount, note = nil)
    @transaction_service ||= LoyaltyTokenTransactionService.new(self)
    @transaction_service.transfer_to(recipient, amount, note)
  end
  
  # Delegated to LoyaltyTokenTransactionService
  def redeem_for_discount(amount)
    @transaction_service ||= LoyaltyTokenTransactionService.new(self)
    @transaction_service.redeem_for_discount(amount)
  end
  
  # Delegated to LoyaltyTokenConversionService
  def self.usd_to_tokens(usd_amount)
    LoyaltyTokenConversionService.usd_to_tokens(usd_amount)
  end

  def self.tokens_to_usd(token_amount)
    LoyaltyTokenConversionService.tokens_to_usd(token_amount)
  end
  
  # Delegated to LoyaltyTokenStakingService
  def stake(amount, duration_days)
    @staking_service ||= LoyaltyTokenStakingService.new(self)
    @staking_service.stake(amount, duration_days)
  end
  
  # Delegated to LoyaltyTokenStakingService
  def unstake(reward_id)
    @staking_service ||= LoyaltyTokenStakingService.new(self)
    @staking_service.unstake(reward_id)
  end
  
  # Delegated to LoyaltyTokenConversionService
  def value_usd
    @conversion_service ||= LoyaltyTokenConversionService.new(self)
    @conversion_service.value_usd
  end
  
  # Delegated to LoyaltyTokenAnalyticsService
  def pending_rewards
    @analytics_service ||= LoyaltyTokenAnalyticsService.new(self)
    @analytics_service.pending_rewards
  end
  
  # Delegated to LoyaltyTokenAnalyticsService
  def transaction_history(limit = 50)
    @analytics_service ||= LoyaltyTokenAnalyticsService.new(self)
    @analytics_service.transaction_history(limit)
  end
  
  # Delegated to LoyaltyTokenExportService
  def export_to_wallet(wallet_address)
    @export_service ||= LoyaltyTokenExportService.new(self)
    @export_service.export_to_wallet(wallet_address)
  end
  
  private

  # calculate_staking_apy is now handled in LoyaltyTokenStakingService
end

