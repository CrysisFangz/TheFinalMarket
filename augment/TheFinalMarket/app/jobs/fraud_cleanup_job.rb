class FraudCleanupJob < ApplicationJob
  queue_as :low_priority
  
  # Clean up old fraud detection data
  def perform
    # Remove old fraud checks (keep 90 days)
    deleted_checks = FraudCheck.where('created_at < ?', 90.days.ago).delete_all
    Rails.logger.info "Deleted #{deleted_checks} old fraud checks"
    
    # Remove old trust scores (keep last 10 per user)
    User.find_each do |user|
      old_scores = user.trust_scores.order(created_at: :desc).offset(10)
      deleted_scores = old_scores.delete_all
    end
    
    # Remove old behavioral patterns (keep 60 days)
    deleted_patterns = BehavioralPattern.where('created_at < ?', 60.days.ago).delete_all
    Rails.logger.info "Deleted #{deleted_patterns} old behavioral patterns"
    
    # Remove expired IP blacklist entries
    deleted_ips = IpBlacklist.where('expires_at < ?', Time.current).where(permanent: false).delete_all
    Rails.logger.info "Deleted #{deleted_ips} expired IP blacklist entries"
    
    # Remove resolved fraud alerts (keep 30 days)
    deleted_alerts = FraudAlert.where(resolved: true).where('resolved_at < ?', 30.days.ago).delete_all
    Rails.logger.info "Deleted #{deleted_alerts} old resolved fraud alerts"
    
    Rails.logger.info "Fraud cleanup completed successfully"
  rescue => e
    Rails.logger.error "Failed to complete fraud cleanup: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end

