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
  
  # Business logic methods are now handled by WalletCardService for separation of concerns.
  # Use WalletCardService.new(self).set_as_default! instead of direct method call.

  # Presentation methods are now handled by WalletCardPresenter.
  # Use WalletCardPresenter.new(self).display_name instead of direct method call.

  # Delegate to service for business operations
  delegate :set_as_default!, :expired?, :remove!, to: :service

  # Delegate to presenter for display operations
  delegate :masked_number, :display_name, to: :presenter

  private

  def service
    @service ||= WalletCardService.new(self)
  end

  def presenter
    @presenter ||= WalletCardPresenter.new(self)
  end
end

