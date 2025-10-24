class SendVerificationCodeJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(two_factor_auth_id, method, code)
    two_factor_auth = TwoFactorAuthentication.find(two_factor_auth_id)

    case method.to_sym
    when :sms
      send_sms(two_factor_auth, code)
    when :email
      send_email(two_factor_auth, code)
    else
      Rails.logger.error("Unknown verification method: #{method} for user #{two_factor_auth.user_id}")
    end
  rescue => e
    Rails.logger.error("Error sending verification code: #{e.message}")
    raise
  end

  private

  def send_sms(two_factor_auth, code)
    # Integration with SMS service (e.g., Twilio)
    # TwilioService.send_sms(two_factor_auth.user.phone_number, "Your verification code is: #{code}")
    Rails.logger.info("Sending SMS to #{two_factor_auth.user.phone_number} with code: #{code}")
    # Actual implementation would call the SMS service
  end

  def send_email(two_factor_auth, code)
    TwoFactorMailer.verification_code(two_factor_auth.user, code).deliver_now
  end
end