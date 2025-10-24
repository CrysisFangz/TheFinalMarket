class VerificationStrategies::HardwareKeyStrategy < VerificationStrategy
  def verify(code)
    # Hardware key verification, e.g., U2F
    return false unless two_factor_auth.hardware_key?

    # Placeholder: integrate with hardware key service
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