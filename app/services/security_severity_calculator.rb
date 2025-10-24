class SecuritySeverityCalculator
  SEVERITY_MAP = {
    security_breach: :critical,
    suspicious_activity: :high,
    account_locked: :high,
    login_failure: :medium,
    failed_authorization: :medium,
    password_change: :low,
    two_factor_enabled: :low
  }.freeze

  def self.calculate(event_type, details)
    SEVERITY_MAP.fetch(event_type.to_sym, :info)
  end
end