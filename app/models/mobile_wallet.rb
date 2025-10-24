class MobileWallet < ApplicationRecord
  belongs_to :user
  has_many :wallet_cards, dependent: :destroy
  has_many :wallet_transactions, dependent: :destroy
  has_many :wallet_passes, dependent: :destroy
  
  validates :user, presence: true
  validates :wallet_id, presence: true, uniqueness: true
  
  enum status: {
    active: 0,
    suspended: 1,
    closed: 2
  }
  
  # Scopes
  scope :active_wallets, -> { where(status: :active) }
  
  # Delegated to MobileWalletManagementService
  def self.create_for_user(user)
    MobileWalletManagementService.create_for_user(user)
  end
  
  # Delegated to MobileWalletTransactionService
  def add_funds(amount_cents, source, metadata = {})
    @transaction_service ||= MobileWalletTransactionService.new(self)
    @transaction_service.add_funds(amount_cents, source, metadata)
  end
  
  # Delegated to MobileWalletTransactionService
  def deduct_funds(amount_cents, purpose, metadata = {})
    @transaction_service ||= MobileWalletTransactionService.new(self)
    @transaction_service.deduct_funds(amount_cents, purpose, metadata)
  end
  
  # Delegated to MobileWalletCardService
  def add_card(card_params)
    @card_service ||= MobileWalletCardService.new(self)
    @card_service.add_card(card_params)
  end
  
  # Delegated to MobileWalletPassService
  def add_pass(pass_params)
    @pass_service ||= MobileWalletPassService.new(self)
    @pass_service.add_pass(pass_params)
  end
  
  # Delegated to MobileWalletAnalyticsService
  def balance
    @analytics_service ||= MobileWalletAnalyticsService.new(self)
    @analytics_service.balance
  end
  
  # Delegated to MobileWalletAnalyticsService
  def transaction_history(limit: 50)
    @analytics_service ||= MobileWalletAnalyticsService.new(self)
    @analytics_service.transaction_history(limit: limit)
  end
  
  # Delegated to MobileWalletCardService
  def default_card
    @card_service ||= MobileWalletCardService.new(self)
    @card_service.default_card
  end
  
  # Get wallet summary
  def summary
    {
      wallet_id: wallet_id,
      balance: balance,
      balance_cents: balance_cents,
      total_cards: wallet_cards.active.count,
      total_passes: wallet_passes.active.count,
      total_transactions: wallet_transactions.count,
      last_transaction: wallet_transactions.order(processed_at: :desc).first&.processed_at
    }
  end
  
  # Suspend wallet
  def suspend!(reason = nil)
    update!(
      status: :suspended,
      suspended_at: Time.current,
      suspension_reason: reason
    )
  end
  
  # Reactivate wallet
  def reactivate!
    update!(
      status: :active,
      suspended_at: nil,
      suspension_reason: nil
    )
  end
  
  private

  # generate_wallet_id is now handled in MobileWalletManagementService
end

