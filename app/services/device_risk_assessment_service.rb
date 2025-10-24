class DeviceRiskAssessmentService
  def self.calculate_risk_score(device)
    score = 0

    # New device
    score += 10 if device.new_device?

    # Shared device
    score += 20 if device.shared_device?

    # Suspicious flag
    score += 30 if device.suspicious?

    # High access count in short time
    if device.created_at > 1.day.ago && device.access_count > 50
      score += 15
    end

    # VPN/Proxy detected
    score += 25 if device.device_info.dig('vpn_detected')

    # Inconsistent location
    score += 20 if GeolocationService.inconsistent_location?(device)

    [score, 100].min
  end
end