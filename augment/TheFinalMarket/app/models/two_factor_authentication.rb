class TwoFactorAuthentication < ApplicationRecord
  belongs_to :user
  
  validates :secret_key, presence: true
  validates :auth_method, presence: true
  
  encrypts :secret_key
  encrypts :backup_codes
  
  scope :active, -> { where(enabled: true) }
  scope :by_method, ->(method) { where(auth_method: method) }
  
  # Authentication methods
  enum auth_method: {
    totp: 0,           # Time-based One-Time Password (Google Authenticator, Authy)
    sms: 1,            # SMS verification
    email: 2,          # Email verification
    biometric: 3,      # Fingerprint, Face ID
    hardware_key: 4    # YubiKey, security keys
  }
  
  # Generate secret key for TOTP
  def self.generate_secret
    ROTP::Base32.random
  end
  
  # Generate backup codes
  def self.generate_backup_codes(count = 10)
    Array.new(count) { SecureRandom.hex(4) }
  end
  
  # Verify TOTP code
  def verify_totp(code)
    return false unless totp?
    
    totp = ROTP::TOTP.new(secret_key)
    verified = totp.verify(code, drift_behind: 30, drift_ahead: 30)
    
    if verified
      update!(last_used_at: Time.current)
      true
    else
      false
    end
  end
  
  # Verify SMS code
  def verify_sms(code)
    return false unless sms?
    return false if verification_code_expired?
    
    if verification_code == code
      update!(last_used_at: Time.current, verification_code: nil, verification_code_sent_at: nil)
      true
    else
      false
    end
  end
  
  # Verify email code
  def verify_email(code)
    return false unless email?
    return false if verification_code_expired?
    
    if verification_code == code
      update!(last_used_at: Time.current, verification_code: nil, verification_code_sent_at: nil)
      true
    else
      false
    end
  end
  
  # Verify backup code
  def verify_backup_code(code)
    codes = JSON.parse(backup_codes || '[]')
    
    if codes.include?(code)
      codes.delete(code)
      update!(backup_codes: codes.to_json, last_used_at: Time.current)
      true
    else
      false
    end
  end
  
  # Send verification code
  def send_verification_code
    code = generate_verification_code
    
    case auth_method.to_sym
    when :sms
      send_sms_code(code)
    when :email
      send_email_code(code)
    end
    
    update!(
      verification_code: code,
      verification_code_sent_at: Time.current
    )
  end
  
  # Get QR code for TOTP setup
  def provisioning_uri
    return nil unless totp?
    
    totp = ROTP::TOTP.new(secret_key)
    totp.provisioning_uri(user.email)
  end
  
  # Get QR code as SVG
  def qr_code_svg
    return nil unless totp?
    
    require 'rqrcode'
    qr = RQRCode::QRCode.new(provisioning_uri)
    qr.as_svg(module_size: 4)
  end
  
  private
  
  def generate_verification_code
    rand(100000..999999).to_s
  end
  
  def verification_code_expired?
    return true unless verification_code_sent_at
    
    verification_code_sent_at < 10.minutes.ago
  end
  
  def send_sms_code(code)
    # Integration with SMS service (Twilio, etc.)
    # TwilioService.send_sms(user.phone_number, "Your verification code is: #{code}")
  end
  
  def send_email_code(code)
    TwoFactorMailer.verification_code(user, code).deliver_later
  end
end

