class DeviceEvaluationService
  def self.evaluate(rule, context)
    return false unless context[:device_fingerprint]

    fingerprint = DeviceFingerprint.find_by(fingerprint_hash: context[:device_fingerprint])
    return false unless fingerprint

    fingerprint.blocked? || fingerprint.suspicious?
  end
end