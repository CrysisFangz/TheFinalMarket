class PrivacySetting < ApplicationRecord
  belongs_to :user
  
  # Privacy preferences
  serialize :data_sharing_preferences, JSON
  serialize :marketing_preferences, JSON
  serialize :visibility_preferences, JSON
  
  # GDPR compliance
  validates :data_processing_consent, inclusion: { in: [true, false] }
  validates :marketing_consent, inclusion: { in: [true, false] }
  
  # Default privacy settings
  after_initialize :set_defaults, if: :new_record?
  
  # Data retention
  enum data_retention_period: {
    minimal: 0,      # 30 days
    standard: 1,     # 1 year
    extended: 2,     # 3 years
    maximum: 3       # 7 years
  }
  
  # Export user data (GDPR right to data portability)
  def export_user_data
    {
      personal_info: export_personal_info,
      orders: export_orders,
      reviews: export_reviews,
      messages: export_messages,
      activity: export_activity,
      preferences: export_preferences
    }
  end
  
  # Delete user data (GDPR right to erasure)
  def delete_user_data(scope = :all)
    case scope
    when :all
      anonymize_all_data
    when :personal
      anonymize_personal_data
    when :activity
      delete_activity_data
    when :marketing
      delete_marketing_data
    end
  end
  
  # Check if data can be shared
  def can_share_data?(purpose)
    return false unless data_processing_consent
    
    preferences = data_sharing_preferences || {}
    preferences[purpose.to_s] != false
  end
  
  # Check if marketing is allowed
  def marketing_allowed?(channel)
    return false unless marketing_consent
    
    preferences = marketing_preferences || {}
    preferences[channel.to_s] != false
  end
  
  # Check visibility setting
  def visible_to?(scope)
    preferences = visibility_preferences || {}
    preferences[scope.to_s] != 'hidden'
  end
  
  # Generate privacy report
  def privacy_report
    {
      data_collected: data_collected_summary,
      data_shared: data_shared_summary,
      third_parties: third_party_sharing_summary,
      retention_policy: retention_policy_summary,
      your_rights: user_rights_summary
    }
  end
  
  private
  
  def set_defaults
    self.data_processing_consent ||= false
    self.marketing_consent ||= false
    self.data_retention_period ||= :standard
    self.data_sharing_preferences ||= default_data_sharing_preferences
    self.marketing_preferences ||= default_marketing_preferences
    self.visibility_preferences ||= default_visibility_preferences
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
  
  def export_personal_info
    user.attributes.slice('name', 'email', 'phone_number', 'created_at')
  end
  
  def export_orders
    user.orders.map do |order|
      {
        id: order.id,
        total: order.total_cents / 100.0,
        created_at: order.created_at,
        items: order.line_items.count
      }
    end
  end
  
  def export_reviews
    user.reviews.map do |review|
      {
        product: review.product.name,
        rating: review.rating,
        comment: review.comment,
        created_at: review.created_at
      }
    end
  end
  
  def export_messages
    user.messages.map do |message|
      {
        content: message.content,
        created_at: message.created_at
      }
    end
  end
  
  def export_activity
    {
      login_count: user.sign_in_count,
      last_login: user.last_sign_in_at,
      page_views: user.page_views&.count || 0
    }
  end
  
  def export_preferences
    {
      privacy_settings: attributes,
      notification_preferences: user.notification_preferences
    }
  end
  
  def anonymize_all_data
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
  
  def anonymize_personal_data
    user.update!(
      name: "User #{user.id}",
      phone_number: nil
    )
  end
  
  def delete_activity_data
    # Delete browsing history, search history, etc.
    user.page_views&.destroy_all
    user.search_queries&.destroy_all
  end
  
  def delete_marketing_data
    # Remove from marketing lists
    user.update!(marketing_consent: false)
  end
  
  def data_collected_summary
    [
      'Account information (name, email, phone)',
      'Order history and purchase data',
      'Browsing and search history',
      'Device and location information',
      'Communication preferences'
    ]
  end
  
  def data_shared_summary
    shared = []
    
    if can_share_data?(:analytics)
      shared << 'Analytics providers (anonymized)'
    end
    
    if can_share_data?(:personalization)
      shared << 'Recommendation engine'
    end
    
    shared
  end
  
  def third_party_sharing_summary
    {
      'Payment processors' => 'Required for transactions',
      'Shipping carriers' => 'Required for delivery',
      'Analytics providers' => can_share_data?(:analytics) ? 'Enabled' : 'Disabled',
      'Marketing partners' => can_share_data?(:third_party_marketing) ? 'Enabled' : 'Disabled'
    }
  end
  
  def retention_policy_summary
    periods = {
      minimal: '30 days',
      standard: '1 year',
      extended: '3 years',
      maximum: '7 years'
    }
    
    "Your data is retained for #{periods[data_retention_period.to_sym]}"
  end
  
  def user_rights_summary
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

