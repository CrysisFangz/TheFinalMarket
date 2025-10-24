class VerificationStrategyFactory
  STRATEGIES = {
    'totp' => VerificationStrategies::TotpStrategy,
    'sms' => VerificationStrategies::SmsStrategy,
    'email' => VerificationStrategies::EmailStrategy,
    'biometric' => VerificationStrategies::BiometricStrategy,
    'hardware_key' => VerificationStrategies::HardwareKeyStrategy
  }.freeze

  def self.for(two_factor_auth)
    strategy_class = STRATEGIES[two_factor_auth.auth_method.to_s]
    raise ArgumentError, "Unknown auth method: #{two_factor_auth.auth_method}" unless strategy_class

    strategy_class.new(two_factor_auth)
  end
end