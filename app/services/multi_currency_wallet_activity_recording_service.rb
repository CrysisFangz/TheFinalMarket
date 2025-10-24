# MultiCurrencyWalletActivityRecordingService
# Handles wallet activity recording and audit trails
class MultiCurrencyWalletActivityRecordingService
  def initialize(wallet)
    @wallet = wallet
  end

  def record_activity!(activity_type, details = {})
    @wallet.wallet_activities.create!(
      activity_type: activity_type,
      details: details,
      ip_address: details[:ip_address],
      user_agent: details[:user_agent],
      geographic_context: extract_geographic_context(details),
      occurred_at: Time.current
    )

    @wallet.touch(:last_activity_at)
  end

  private

  def extract_geographic_context(details)
    {
      ip_address: details[:ip_address],
      user_agent: details[:user_agent],
      timezone: details[:timezone],
      language: details[:language],
      country_code: details[:country_code],
      region: details[:region]
    }
  end
end