require 'rotp'

class TwoFactorAuthenticationService
  def self.generate_secret
    ROTP::Base32.random
  end

  def self.generate_backup_codes(count = 10)
    Array.new(count) { SecureRandom.hex(4) }
  end

  def self.verify(two_factor_auth, code)
    strategy = VerificationStrategyFactory.for(two_factor_auth)
    strategy.verify(code)
  rescue => e
    Rails.logger.error("Error verifying code for user #{two_factor_auth.user_id}: #{e.message}")
    false
  end

  def self.send_verification_code(two_factor_auth)
    strategy = VerificationStrategyFactory.for(two_factor_auth)
    strategy.send_code
  end

  def self.provisioning_uri(two_factor_auth)
    strategy = VerificationStrategyFactory.for(two_factor_auth)
    strategy.provisioning_uri
  end

  def self.qr_code_svg(two_factor_auth)
    strategy = VerificationStrategyFactory.for(two_factor_auth)
    strategy.qr_code_svg
  end

  def self.verify_backup_code(two_factor_auth, code)
    codes = JSON.parse(two_factor_auth.backup_codes || '[]')

    if codes.include?(code)
      codes.delete(code)
      two_factor_auth.update!(backup_codes: codes.to_json, last_used_at: Time.current)
      true
    else
      false
    end
  end
end