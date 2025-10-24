class DeviceFingerprintPresenter
  def initialize(device_fingerprint)
    @device_fingerprint = device_fingerprint
  end

  def as_json(options = {})
    {
      id: @device_fingerprint.id,
      fingerprint_hash: @device_fingerprint.fingerprint_hash,
      user_id: @device_fingerprint.user_id,
      device_info: @device_fingerprint.device_info,
      last_ip_address: @device_fingerprint.last_ip_address,
      last_seen_at: @device_fingerprint.last_seen_at,
      access_count: @device_fingerprint.access_count,
      suspicious: @device_fingerprint.suspicious?,
      suspicious_reason: @device_fingerprint.suspicious_reason,
      suspicious_at: @device_fingerprint.suspicious_at,
      blocked: @device_fingerprint.blocked?,
      blocked_reason: @device_fingerprint.blocked_reason,
      blocked_at: @device_fingerprint.blocked_at,
      risk_score: @device_fingerprint.risk_score,
      new_device: @device_fingerprint.new_device?,
      shared_device: @device_fingerprint.shared_device?,
      associated_users: @device_fingerprint.associated_users.pluck(:id),
      created_at: @device_fingerprint.created_at,
      updated_at: @device_fingerprint.updated_at
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end