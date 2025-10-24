# frozen_string_literal: true

# Service for deleting and anonymizing user data in compliance with GDPR.
# Ensures data integrity and provides audit trails for all operations.
class DataDeletionService
  # Deletes or anonymizes user data based on the specified scope.
  # @param privacy_setting [PrivacySetting] The privacy setting of the user.
  # @param scope [Symbol] The scope of deletion (:all, :personal, :activity, :marketing).
  def self.delete_user_data(privacy_setting, scope = :all)
    user = privacy_setting.user

    case scope
    when :all
      anonymize_all_data(user)
    when :personal
      anonymize_personal_data(user)
    when :activity
      delete_activity_data(user)
    when :marketing
      delete_marketing_data(user)
    else
      raise ArgumentError, "Invalid deletion scope: #{scope}"
    end

    # Publish event for auditability
    EventPublisher.publish('user_data_deleted', { user_id: user.id, scope: scope })
  rescue StandardError => e
    Rails.logger.error("Data deletion failed for user #{user.id}, scope #{scope}: #{e.message}")
    raise ArgumentError, "Failed to delete user data: #{e.message}"
  end

  private

  def self.anonymize_all_data(user)
    user.transaction do
      user.update!(
        name: "Deleted User #{user.id}",
        email: "deleted_#{user.id}@example.com",
        phone_number: nil,
        deleted_at: Time.current
      )

      # Anonymize reviews
      user.reviews.update_all(user_name: 'Anonymous')

      # Delete messages
      user.messages.destroy_all
    end
  end

  def self.anonymize_personal_data(user)
    user.update!(
      name: "User #{user.id}",
      phone_number: nil
    )
  end

  def self.delete_activity_data(user)
    # Delete browsing history, search history, etc.
    user.page_views&.destroy_all
    user.search_queries&.destroy_all
  end

  def self.delete_marketing_data(user)
    # Remove from marketing lists
    user.update!(marketing_consent: false)
  end
end