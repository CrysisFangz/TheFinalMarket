# frozen_string_literal: true

# Service for generating comprehensive privacy reports for users.
# Optimized with caching to reduce computational overhead.
class PrivacyReportService
  # Generates a privacy report for the given privacy setting.
  # @param privacy_setting [PrivacySetting] The privacy setting of the user.
  # @return [Hash] The privacy report.
  def self.generate_report(privacy_setting)
    cache_key = "privacy_report_#{privacy_setting.id}_#{privacy_setting.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      {
        data_collected: data_collected_summary,
        data_shared: data_shared_summary(privacy_setting),
        third_parties: third_party_sharing_summary(privacy_setting),
        retention_policy: retention_policy_summary(privacy_setting),
        your_rights: user_rights_summary
      }
    end
  rescue StandardError => e
    Rails.logger.error("Privacy report generation failed for privacy_setting #{privacy_setting.id}: #{e.message}")
    raise ArgumentError, "Failed to generate privacy report: #{e.message}"
  end

  private

  def self.data_collected_summary
    [
      'Account information (name, email, phone)',
      'Order history and purchase data',
      'Browsing and search history',
      'Device and location information',
      'Communication preferences'
    ]
  end

  def self.data_shared_summary(privacy_setting)
    shared = []

    if privacy_setting.can_share_data?(:analytics)
      shared << 'Analytics providers (anonymized)'
    end

    if privacy_setting.can_share_data?(:personalization)
      shared << 'Recommendation engine'
    end

    shared
  end

  def self.third_party_sharing_summary(privacy_setting)
    {
      'Payment processors' => 'Required for transactions',
      'Shipping carriers' => 'Required for delivery',
      'Analytics providers' => privacy_setting.can_share_data?(:analytics) ? 'Enabled' : 'Disabled',
      'Marketing partners' => privacy_setting.can_share_data?(:third_party_marketing) ? 'Enabled' : 'Disabled'
    }
  end

  def self.retention_policy_summary(privacy_setting)
    periods = {
      minimal: '30 days',
      standard: '1 year',
      extended: '3 years',
      maximum: '7 years'
    }

    "Your data is retained for #{periods[privacy_setting.data_retention_period.to_sym]}"
  end

  def self.user_rights_summary
    [
      'Right to access your data',
      'Right to rectify incorrect data',
      'Right to erase your data',
      'Right to restrict processing',
      'Right to data portability',
      'Right to object to processing',
      'Right to withdraw consent'
    ]
  end
end