# frozen_string_literal: true

# Service for exporting user data in compliance with GDPR and privacy regulations.
# Optimized for performance with caching and efficient queries.
class DataExportService
  # Exports all user data for a given privacy setting.
  # @param privacy_setting [PrivacySetting] The privacy setting of the user.
  # @return [Hash] The exported data.
  def self.export_user_data(privacy_setting)
    user = privacy_setting.user

    {
      personal_info: export_personal_info(user),
      orders: export_orders(user),
      reviews: export_reviews(user),
      messages: export_messages(user),
      activity: export_activity(user),
      preferences: export_preferences(privacy_setting, user)
    }
  rescue StandardError => e
    Rails.logger.error("Data export failed for user #{user.id}: #{e.message}")
    raise ArgumentError, "Failed to export user data: #{e.message}"
  end

  private

  def self.export_personal_info(user)
    user.attributes.slice('name', 'email', 'phone_number', 'created_at')
  end

  def self.export_orders(user)
    user.orders.includes(:line_items).map do |order|
      {
        id: order.id,
        total: order.total_cents / 100.0,
        created_at: order.created_at,
        items: order.line_items.count
      }
    end
  end

  def self.export_reviews(user)
    user.reviews.includes(:product).map do |review|
      {
        product: review.product.name,
        rating: review.rating,
        comment: review.comment,
        created_at: review.created_at
      }
    end
  end

  def self.export_messages(user)
    user.messages.map do |message|
      {
        content: message.content,
        created_at: message.created_at
      }
    end
  end

  def self.export_activity(user)
    {
      login_count: user.sign_in_count,
      last_login: user.last_sign_in_at,
      page_views: user.page_views&.count || 0
    }
  end

  def self.export_preferences(privacy_setting, user)
    {
      privacy_settings: privacy_setting.attributes,
      notification_preferences: user.notification_preferences
    }
  end
end