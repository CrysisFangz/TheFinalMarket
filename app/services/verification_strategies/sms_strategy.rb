class VerificationStrategies::SmsStrategy < VerificationStrategy
  def verify(code)
    return false unless two_factor_auth.sms?
    return false if verification_code_expired?

    if two_factor_auth.verification_code == code
      two_factor_auth.update!(last_used_at: Time.current, verification_code: nil, verification_code_sent_at: nil)
      Rails.logger.info("SMS verification successful for user #{two_factor_auth.user_id}")
      true
    else
      Rails.logger.warn("SMS verification failed for user #{two_factor_auth.user_id}")
      false
    end
  end

  def send_code
    code = generate_verification_code
    # Enqueue background job for sending SMS
    SendVerificationCodeJob.perform_later(two_factor_auth.id, :sms, code)
    two_factor_auth.update!(verification_code: code, verification_code_sent_at: Time.current)
  end

  def provisioning_uri
    nil
  end

  def qr_code_svg
    nil
  end
end