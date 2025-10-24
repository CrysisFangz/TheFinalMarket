# frozen_string_literal: true

# Service for cleaning up old product views to maintain optimal database performance.
# Ensures efficient storage management and prevents database bloat.
class ProductViewCleanupService
  MAX_VIEWS_PER_USER = 100

  # Cleans up old product views for a user.
  # @param user [User] The user whose views to clean up.
  # @return [Integer] Number of views deleted.
  def self.cleanup_user_views(user)
    old_views = user.product_views
                   .order(created_at: :desc)
                   .offset(MAX_VIEWS_PER_USER)

    deleted_count = old_views.count
    old_views.destroy_all

    # Publish event
    EventPublisher.publish('product_views_cleaned', {
      user_id: user.id,
      views_deleted: deleted_count
    })

    deleted_count
  rescue StandardError => e
    Rails.logger.error("Product view cleanup failed for user #{user.id}: #{e.message}")
    0
  end

  # Cleans up old views for a specific product view.
  # @param product_view [ProductView] The product view that triggered cleanup.
  # @return [Integer] Number of views deleted.
  def self.cleanup_after_view_creation(product_view)
    cleanup_user_views(product_view.user)
  end
end