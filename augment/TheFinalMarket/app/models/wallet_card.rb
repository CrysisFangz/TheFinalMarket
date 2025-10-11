class WalletCard < ApplicationRecord
  belongs_to :mobile_wallet
  
  validates :mobile_wallet, presence: true
  validates :card_type, presence: true
  validates :last_four, presence: true, length: { is: 4 }
  
  enum card_type: {
    credit_card: 0,
    debit_card: 1,
    prepaid_card: 2,
    bank_account: 3
  }
  
  enum card_brand: {
    visa: 0,
    mastercard: 1,
    amex: 2,
    discover: 3,
    other: 4
  }
  
  enum status: {
    active: 0,
    expired: 1,
    removed: 2
  }
  
  # Scopes
  scope :active_cards, -> { where(status: :active) }
  scope :default_cards, -> { where(is_default: true) }
  
  # Set as default card
  def set_as_default!
    mobile_wallet.wallet_cards.update_all(is_default: false)
    update!(is_default: true)
  end
  
  # Check if card is expired
  def expired?
    return false unless expiry_month && expiry_year
    
    expiry_date = Date.new(expiry_year, expiry_month, -1)
    expiry_date < Date.current
  end
  
  # Remove card
  def remove!
    update!(status: :removed, removed_at: Time.current)
  end
  
  # Get masked card number
  def masked_number
    "•••• •••• •••• #{last_four}"
  end
  
  # Get card display name
  def display_name
    "#{card_brand.titleize} #{card_type.titleize.gsub('_', ' ')} ••#{last_four}"
  end
end

