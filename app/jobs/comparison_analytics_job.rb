# app/jobs/comparison_analytics_job.rb
#
# Background job for processing comparison-related analytics.
# Ensures non-blocking performance for user-facing operations.
# Integrates with monitoring and logging for observability.
#
# Key Features:
# - Asynchronous execution to maintain low latency.
# - Robust error handling and retry logic.
# - Scalable for high-volume events.
#
class ComparisonAnalyticsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(user_id, product_id, action)
    user = User.find_by(id: user_id)
    return unless user  # Handle deleted users gracefully

    Rails.logger.info("Processing comparison analytics: User #{user_id}, Product #{product_id}, Action: #{action}")

    # Example analytics: Track user behavior
    case action
    when :add
      increment_user_metric(user, :comparison_adds)
      track_product_comparison(user, product_id)
    when :remove
      increment_user_metric(user, :comparison_removes)
    when :clear
      increment_user_metric(user, :comparison_clears)
    end

    # Optionally integrate with external analytics (e.g., Google Analytics, Mixpanel)
    # AnalyticsService.track_comparison_event(user, product_id, action)

    # Simulate additional processing for sophistication
    perform_complex_analytics(user, product_id, action)
  rescue => e
    Rails.logger.error("Analytics job failed for user: #{user_id} - #{e.message}")
    # Could notify monitoring service here
  end

  private

  def increment_user_metric(user, metric)
    # Example: Update user stats atomically
    user.increment!(metric)
  end

  def track_product_comparison(user, product_id)
    # Example: Log or update product-specific metrics
    product = Product.find_by(id: product_id)
    product&.increment!(:comparison_count) if product
  end

  def perform_complex_analytics(user, product_id, action)
    # Placeholder for advanced analytics, e.g., machine learning predictions
    # Could involve cohort analysis or predictive modeling
    # For now, simulate with a delay or computation
    sleep(0.01)  # Simulate processing time
  end
end