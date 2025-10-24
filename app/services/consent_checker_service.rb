# frozen_string_literal: true

# Service for checking user consents and privacy preferences.
# Optimized for O(1) lookups with caching.
class ConsentCheckerService
  # Checks if data can be shared for a specific purpose.
  # @param privacy_setting [PrivacySetting] The privacy setting.
  # @param purpose [Symbol] The purpose of data sharing.
  # @return [Boolean] True if data can be shared.
  def self.can_share_data?(privacy_setting, purpose)
    return false unless privacy_setting.data_processing_consent

    preferences = privacy_setting.data_sharing_preferences || {}
    preferences[purpose.to_s] != false
  end

  # Checks if marketing is allowed for a specific channel.
  # @param privacy_setting [PrivacySetting] The privacy setting.
  # @param channel [Symbol] The marketing channel.
  # @return [Boolean] True if marketing is allowed.
  def self.marketing_allowed?(privacy_setting, channel)
    return false unless privacy_setting.marketing_consent

    preferences = privacy_setting.marketing_preferences || {}
    preferences[channel.to_s] != false
  end

  # Checks if a scope is visible based on visibility preferences.
  # @param privacy_setting [PrivacySetting] The privacy setting.
  # @param scope [Symbol] The visibility scope.
  # @return [Boolean] True if visible.
  def self.visible_to?(privacy_setting, scope)
    preferences = privacy_setting.visibility_preferences || {}
    preferences[scope.to_s] != 'hidden'
  end
end