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

  # Delegate business logic to service layer
  def verify(code)
    TwoFactorAuthenticationService.verify(self, code)
  end

  def send_verification_code
    TwoFactorAuthenticationService.send_verification_code(self)
  end

  def provisioning_uri
    TwoFactorAuthenticationService.provisioning_uri(self)
  end

  def qr_code_svg
    TwoFactorAuthenticationService.qr_code_svg(self)
  end

  def verify_backup_code(code)
    TwoFactorAuthenticationService.verify_backup_code(self, code)
  end

  # Class methods delegated to service
  def self.generate_secret
    TwoFactorAuthenticationService.generate_secret
  end

  def self.generate_backup_codes(count = 10)
    TwoFactorAuthenticationService.generate_backup_codes(count)
  end
end

