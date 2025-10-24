# MultiCurrencyWalletGeolocationService
# Handles geolocation overrides and restrictions
class MultiCurrencyWalletGeolocationService
  def initialize(wallet)
    @wallet = wallet
  end

  def create_geolocation_override!(override_params)
    @wallet.geolocation_overrides.create!(
      override_type: override_params[:override_type],
      restriction_level: override_params[:restriction_level] || :none,
      justification: override_params[:justification],
      expires_at: override_params[:expires_at],
      created_by: override_params[:created_by] || 'system',
      override_data: override_params[:override_data] || {}
    )
  end

  def active_geolocation_overrides
    @wallet.geolocation_overrides.where('expires_at IS NULL OR expires_at > ?', Time.current)
  end

  def global_commerce_restrictions_applicable?
    return false if @wallet.global_commerce_enabled? && @wallet.geofence_override?

    active_restrictions = active_geolocation_overrides.where(restriction_level: [:country, :region])
    active_restrictions.exists?
  end
end