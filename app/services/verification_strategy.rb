# Base class for verification strategies
class VerificationStrategy
  attr_reader :two_factor_auth

  def initialize(two_factor_auth)
    @two_factor_auth = two_factor_auth
  end

  def verify(code)
    raise NotImplementedError, "Subclasses must implement #verify"
  end

  def send_code
    raise NotImplementedError, "Subclasses must implement #send_code"
  end

  def provisioning_uri
    raise NotImplementedError, "Subclasses must implement #provisioning_uri"
  end

  def qr_code_svg
    raise NotImplementedError, "Subclasses must implement #qr_code_svg"
  end

  private

  def update_last_used
    two_factor_auth.update!(last_used_at: Time.current)
  end

  def generate_verification_code
    rand(100000..999999).to_s
  end

  def verification_code_expired?
    return true unless two_factor_auth.verification_code_sent_at

    two_factor_auth.verification_code_sent_at < 10.minutes.ago
  end
end