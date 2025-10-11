class CryptoPayment < ApplicationRecord
  belongs_to :order
  belongs_to :user
  
  validates :cryptocurrency, presence: true
  validates :amount_crypto, presence: true
  validates :wallet_address, presence: true
  
  scope :pending, -> { where(status: :pending) }
  scope :confirmed, -> { where(status: :confirmed) }
  scope :by_currency, ->(currency) { where(cryptocurrency: currency) }
  
  # Supported cryptocurrencies
  enum cryptocurrency: {
    bitcoin: 0,
    ethereum: 1,
    usdc: 2,
    usdt: 3,
    dai: 4,
    matic: 5,
    bnb: 6
  }
  
  # Payment status
  enum status: {
    pending: 0,
    confirming: 1,
    confirmed: 2,
    failed: 3,
    expired: 4
  }
  
  # Create crypto payment
  def self.create_for_order(order, cryptocurrency)
    # Get current exchange rate
    rate = CryptoExchangeRate.current_rate(cryptocurrency, 'USD')
    amount_crypto = (order.total_cents / 100.0 / rate).round(8)
    
    # Generate payment address
    payment_address = generate_payment_address(cryptocurrency)
    
    create!(
      order: order,
      user: order.user,
      cryptocurrency: cryptocurrency,
      amount_crypto: amount_crypto,
      amount_usd_cents: order.total_cents,
      exchange_rate: rate,
      wallet_address: payment_address,
      expires_at: 30.minutes.from_now,
      status: :pending
    )
  end
  
  # Check payment status
  def check_status
    return if confirmed? || failed? || expired?
    
    # Check if expired
    if expires_at < Time.current
      update!(status: :expired)
      return
    end
    
    # Check blockchain for payment
    blockchain_status = check_blockchain
    
    case blockchain_status[:status]
    when 'received'
      update!(
        status: :confirming,
        transaction_hash: blockchain_status[:tx_hash],
        confirmations: blockchain_status[:confirmations]
      )
    when 'confirmed'
      confirm_payment(blockchain_status)
    end
  end
  
  # Confirm payment
  def confirm_payment(blockchain_data)
    update!(
      status: :confirmed,
      confirmed_at: Time.current,
      transaction_hash: blockchain_data[:tx_hash],
      confirmations: blockchain_data[:confirmations],
      actual_amount_received: blockchain_data[:amount]
    )
    
    # Mark order as paid
    order.update!(
      payment_status: 'paid',
      paid_at: Time.current
    )
    
    # Send confirmation
    CryptoPaymentMailer.payment_confirmed(self).deliver_later
  end
  
  # Get payment QR code
  def payment_qr_code
    require 'rqrcode'
    
    # Create payment URI
    uri = payment_uri
    
    qr = RQRCode::QRCode.new(uri)
    qr.as_svg(module_size: 4)
  end
  
  # Get payment URI
  def payment_uri
    case cryptocurrency.to_sym
    when :bitcoin
      "bitcoin:#{wallet_address}?amount=#{amount_crypto}"
    when :ethereum, :usdc, :usdt, :dai
      "ethereum:#{wallet_address}?value=#{amount_crypto}"
    when :matic
      "polygon:#{wallet_address}?value=#{amount_crypto}"
    when :bnb
      "binance:#{wallet_address}?value=#{amount_crypto}"
    end
  end
  
  # Get block explorer URL
  def block_explorer_url
    return nil unless transaction_hash
    
    base_urls = {
      bitcoin: 'https://blockchain.com/btc/tx',
      ethereum: 'https://etherscan.io/tx',
      usdc: 'https://etherscan.io/tx',
      usdt: 'https://etherscan.io/tx',
      dai: 'https://etherscan.io/tx',
      matic: 'https://polygonscan.com/tx',
      bnb: 'https://bscscan.com/tx'
    }
    
    "#{base_urls[cryptocurrency.to_sym]}/#{transaction_hash}"
  end
  
  # Refund crypto payment
  def refund(refund_address)
    return false unless confirmed?
    
    # Create refund transaction
    refund_tx = create_refund_transaction(refund_address)
    
    update!(
      refunded: true,
      refund_transaction_hash: refund_tx[:hash],
      refunded_at: Time.current
    )
  end
  
  private
  
  def self.generate_payment_address(cryptocurrency)
    # This would integrate with wallet service
    # For now, generate mock address
    case cryptocurrency.to_sym
    when :bitcoin
      "bc1q#{SecureRandom.hex(20)}"
    when :ethereum, :usdc, :usdt, :dai
      "0x#{SecureRandom.hex(20)}"
    when :matic
      "0x#{SecureRandom.hex(20)}"
    when :bnb
      "0x#{SecureRandom.hex(20)}"
    end
  end
  
  def check_blockchain
    # This would query blockchain API
    # For now, return mock data
    {
      status: 'pending',
      tx_hash: nil,
      confirmations: 0,
      amount: 0
    }
  end
  
  def create_refund_transaction(refund_address)
    # This would create blockchain transaction
    # For now, return mock data
    {
      hash: "0x#{SecureRandom.hex(32)}",
      status: 'pending'
    }
  end
end

