# frozen_string_literal: true

# Sidekiq Worker for Asynchronous Admin Dashboard Analytics
# Handles heavy computations in the background to maintain P99 < 10ms latency
class AdminDashboardAnalyticsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :admin_analytics, retry: 3

  def perform(admin_id, computation_type, params = {})
    admin = User.find(admin_id)
    case computation_type
    when 'predictive_analytics'
      result = PredictiveAnalyticsService.new(params[:system_metrics]).forecast_trends
      Rails.cache.write("predictive_analytics_#{admin_id}", result, expires_in: 30.minutes)
    when 'behavioral_analytics'
      result = BehavioralAnalyticsService.new.analyze_user_patterns
      Rails.cache.write("behavioral_analytics_#{admin_id}", result, expires_in: 15.minutes)
    when 'financial_analytics'
      result = FinancialAnalyticsService.new(params[:system_metrics]).calculate_impact
      Rails.cache.write("financial_analytics_#{admin_id}", result, expires_in: 20.minutes)
    else
      raise "Unknown computation type: #{computation_type}"
    end
  rescue StandardError => e
    Rails.logger.error "Analytics Worker Failed: #{e.message}"
    # Report to monitoring system
  end
end