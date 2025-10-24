class VerificationStrategies::BiometricStrategy < VerificationStrategy
  def verify(code)
    # Biometric verification logic, e.g., via external service
    # For simplicity, assume it's verified if enabled
    return false unless two_factor_auth.biometric?

    # Placeholder: integrate with biometric service
    update_last_used
    true
  end

  def send_code
    false
  end

  def provisioning_uri
    nil
  end

  def qr_code_svg
    nil
  end
end