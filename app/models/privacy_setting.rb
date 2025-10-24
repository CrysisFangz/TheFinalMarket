# frozen_string_literal: true

# PrivacySetting model refactored for architectural purity and performance.
# Business logic decoupled into dedicated services for clarity and scalability.
class PrivacySetting < ApplicationRecord
  belongs_to :user

  # Privacy preferences with JSON serialization
  serialize :data_sharing_preferences, JSON
  serialize :marketing_preferences, JSON
  serialize :visibility_preferences, JSON

  # Enhanced validations for GDPR compliance and data integrity
  validates :data_processing_consent, inclusion: { in: [true, false], message: "must be true or false" }
  validates :marketing_consent, inclusion: { in: [true, false], message: "must be true or false" }
  validates :data_sharing_preferences, :marketing_preferences, :visibility_preferences, presence: true

  # Default privacy settings with error handling
  after_initialize :set_defaults, if: :new_record?

  # Event-driven: Publish events on consent changes
  after_save :publish_consent_change_event, if: :saved_change_to_data_processing_consent?

  # Data retention with enum
  enum data_retention_period: {
    minimal: 0,      # 30 days
    standard: 1,     # 1 year
    extended: 2,     # 3 years
    maximum: 3       # 7 years
  }

  # Scope for preloading user to optimize queries
  scope :with_user, -> { includes(:user) }

  # Export user data using dedicated service
  def export_user_data
    DataExportService.export_user_data(self)
  end

  # Delete user data using dedicated service
  def delete_user_data(scope = :all)
    DataDeletionService.delete_user_data(self, scope)
  end

  # Check if data can be shared using service
  def can_share_data?(purpose)
    ConsentCheckerService.can_share_data?(self, purpose)
  end

  # Check if marketing is allowed using service
  def marketing_allowed?(channel)
    ConsentCheckerService.marketing_allowed?(self, channel)
  end

  # Check visibility setting using service
  def visible_to?(scope)
    ConsentCheckerService.visible_to?(self, scope)
  end

  # Generate privacy report using dedicated service
  def privacy_report
    PrivacyReportService.generate_report(self)
  end
  
  private

  def set_defaults
    self.data_processing_consent ||= false
    self.marketing_consent ||= false
    self.data_retention_period ||= :standard
    self.data_sharing_preferences ||= default_data_sharing_preferences
    self.marketing_preferences ||= default_marketing_preferences
    self.visibility_preferences ||= default_visibility_preferences
  rescue StandardError => e
    Rails.logger.error("Failed to set defaults for PrivacySetting #{id}: #{e.message}")
    raise
  end

  def default_data_sharing_preferences
    {
      'analytics' => true,
      'personalization' => true,
      'third_party_marketing' => false,
      'research' => false
    }
  end

  def default_marketing_preferences
    {
      'email' => true,
      'sms' => false,
      'push' => true,
      'phone' => false
    }
  end

  def default_visibility_preferences
    {
      'profile' => 'public',
      'orders' => 'private',
      'reviews' => 'public',
      'wishlists' => 'friends'
    }
  end

  # Publishes consent change event for auditability and compliance
  def publish_consent_change_event
    Rails.logger.info("Privacy consent changed: User=#{user_id}, Consent=#{data_processing_consent}")
    # In a full event system: EventPublisher.publish('privacy_consent_changed', self.attributes)
  end
end

