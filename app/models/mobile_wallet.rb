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
  
  # Create wallet for user
  def self.create_for_user(user)
    create!(
      user: user,
      wallet_id: generate_wallet_id,
      balance_cents: 0,
      status: :active,
      activated_at: Time.current
    )
  end
  
  # Add funds to wallet
  def add_funds(amount_cents, source, metadata = {})
    return false unless active?
    
    transaction = wallet_transactions.create!(
      transaction_type: :credit,
      amount_cents: amount_cents,
      source: source,
      balance_after_cents: balance_cents + amount_cents,
      transaction_data: metadata,
      processed_at: Time.current
    )
    
    increment!(:balance_cents, amount_cents)
    transaction
  end
  
  # Deduct funds from wallet
  def deduct_funds(amount_cents, purpose, metadata = {})
    return false unless active?
    return false if balance_cents < amount_cents
    
    transaction = wallet_transactions.create!(
      transaction_type: :debit,
      amount_cents: amount_cents,
      purpose: purpose,
      balance_after_cents: balance_cents - amount_cents,
      transaction_data: metadata,
      processed_at: Time.current
    )
    
    decrement!(:balance_cents, amount_cents)
    transaction
  end
  
  # Add payment card
  def add_card(card_params)
    wallet_cards.create!(
      card_type: card_params[:card_type],
      last_four: card_params[:last_four],
      card_brand: card_params[:card_brand],
      expiry_month: card_params[:expiry_month],
      expiry_year: card_params[:expiry_year],
      cardholder_name: card_params[:cardholder_name],
      is_default: wallet_cards.empty?,
      token: card_params[:token],
      card_data: card_params[:metadata] || {}
    )
  end
  
  # Add pass (loyalty card, coupon, ticket, etc.)
  def add_pass(pass_params)
    wallet_passes.create!(
      pass_type: pass_params[:pass_type],
      pass_name: pass_params[:pass_name],
      pass_identifier: pass_params[:pass_identifier],
      barcode_value: pass_params[:barcode_value],
      barcode_format: pass_params[:barcode_format],
      expiry_date: pass_params[:expiry_date],
      pass_data: pass_params[:pass_data] || {},
      added_at: Time.current
    )
  end
  
  # Get wallet balance
  def balance
    balance_cents / 100.0
  end
  
  # Get transaction history
  def transaction_history(limit: 50)
    wallet_transactions.order(processed_at: :desc).limit(limit)
  end
  
  # Get default payment card
  def default_card
    wallet_cards.active.find_by(is_default: true) || wallet_cards.active.first
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
  
  def self.generate_wallet_id
    loop do
      wallet_id = "MW#{SecureRandom.hex(8).upcase}"
      break wallet_id unless exists?(wallet_id: wallet_id)
    end
  end
end

