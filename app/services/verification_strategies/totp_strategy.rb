require 'rotp'
require 'rqrcode'

class VerificationStrategies::TotpStrategy < VerificationStrategy
  def verify(code)
    return false unless two_factor_auth.totp?

    cache_key = "totp_verify_#{two_factor_auth.id}_#{code}"
    Rails.cache.fetch(cache_key, expires_in: 30.seconds) do
      totp = ROTP::TOTP.new(two_factor_auth.secret_key)
      verified = totp.verify(code, drift_behind: 30, drift_ahead: 30)

      if verified
        update_last_used
        Rails.logger.info("TOTP verification successful for user #{two_factor_auth.user_id}")
        true
      else
        Rails.logger.warn("TOTP verification failed for user #{two_factor_auth.user_id}")
        false
      end
    end
  end

  def send_code
    # TOTP doesn't require sending codes
    false
  end

  def provisioning_uri
    totp = ROTP::TOTP.new(two_factor_auth.secret_key)
    totp.provisioning_uri(two_factor_auth.user.email)
  end

  def qr_code_svg
    qr = RQRCode::QRCode.new(provisioning_uri)
    qr.as_svg(module_size: 4)
  end
end