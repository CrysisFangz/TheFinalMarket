# MultiCurrencyWalletGlobalCommerceService
# Handles global commerce operations
class MultiCurrencyWalletGlobalCommerceService
  def initialize(wallet)
    @wallet = wallet
  end

  def enable_global_commerce!(geofence_override = true)
    @wallet.update!(
      global_commerce_enabled: true,
      geofence_override: geofence_override,
      global_commerce_activated_at: Time.current,
      allowed_countries: ['*'],
      blocked_countries: []
    )

    @wallet.create_geolocation_override!(
      override_type: :global_commerce,
      restriction_level: :none,
      justification: 'User requested unrestricted global commerce',
      expires_at: nil
    )
  end
end