class WalletPass < ApplicationRecord
  belongs_to :mobile_wallet
  
  validates :mobile_wallet, presence: true
  validates :pass_type, presence: true
  validates :pass_name, presence: true
  validates :pass_identifier, presence: true, uniqueness: { scope: :mobile_wallet_id }
  
  enum pass_type: {
    loyalty_card: 0,
    coupon: 1,
    ticket: 2,
    boarding_pass: 3,
    membership: 4,
    gift_card: 5,
    store_card: 6
  }
  
  enum barcode_format: {
    qr_code: 0,
    code_128: 1,
    pdf417: 2,
    aztec: 3,
    data_matrix: 4
  }
  
  enum status: {
    active: 0,
    expired: 1,
    redeemed: 2,
    removed: 3
  }
  
  # Scopes
  scope :active_passes, -> { where(status: :active).where('expiry_date IS NULL OR expiry_date > ?', Date.current) }
  scope :by_type, ->(type) { where(pass_type: type) }
  
  # Check if pass is expired
  def expired?
    expiry_date.present? && expiry_date < Date.current
  end
  
  # Redeem pass
  def redeem!
    return false if redeemed? || expired?
    
    update!(
      status: :redeemed,
      redeemed_at: Time.current
    )
  end
  
  # Remove pass
  def remove!
    update!(status: :removed, removed_at: Time.current)
  end
  
  # Get pass details
  def details
    {
      pass_type: pass_type,
      pass_name: pass_name,
      barcode_value: barcode_value,
      barcode_format: barcode_format,
      expiry_date: expiry_date,
      status: status,
      data: pass_data
    }
  end
end

