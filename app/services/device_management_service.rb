class DeviceManagementService
  def self.mark_suspicious!(device, reason)
    device.update!(
      suspicious: true,
      suspicious_reason: reason,
      suspicious_at: Time.current
    )
  end

  def self.block!(device, reason)
    device.update!(
      blocked: true,
      blocked_reason: reason,
      blocked_at: Time.current
    )
  end

  def self.unblock!(device)
    device.update!(
      blocked: false,
      blocked_reason: nil,
      blocked_at: nil
    )
  end

  def self.touch_last_seen!(device)
    device.update!(
      last_seen_at: Time.current,
      access_count: device.access_count + 1
    )
  end
end