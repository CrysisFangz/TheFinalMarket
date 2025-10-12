class SecurityScanJob < ApplicationJob
  queue_as :low_priority
  
  def perform
    Rails.logger.info "Starting security scan..."
    
    scan_results = {
      vulnerable_users: scan_vulnerable_users,
      suspicious_activity: scan_suspicious_activity,
      expired_verifications: scan_expired_verifications,
      weak_passwords: scan_weak_passwords,
      inactive_2fa: scan_inactive_2fa
    }
    
    # Generate security report
    SecurityReport.create!(
      scan_date: Date.current,
      results: scan_results,
      recommendations: generate_recommendations(scan_results)
    )
    
    Rails.logger.info "Security scan complete"
    
    # Send report to admins
    SecurityMailer.weekly_security_report(scan_results).deliver_later
  end
  
  private
  
  def scan_vulnerable_users
    User.where('security_score < ?', 50).count
  end
  
  def scan_suspicious_activity
    SecurityAudit.where(event_type: :suspicious_activity)
                 .where('created_at > ?', 7.days.ago)
                 .count
  end
  
  def scan_expired_verifications
    IdentityVerification.where('expires_at < ?', Time.current)
                       .where(status: :approved)
                       .count
  end
  
  def scan_weak_passwords
    # Users who haven't changed password in 90+ days
    User.where('password_changed_at < ?', 90.days.ago).count
  end
  
  def scan_inactive_2fa
    # Users without 2FA enabled
    User.where(two_factor_enabled: false).count
  end
  
  def generate_recommendations(results)
    recommendations = []
    
    if results[:vulnerable_users] > 10
      recommendations << "#{results[:vulnerable_users]} users have low security scores. Consider mandatory security improvements."
    end
    
    if results[:suspicious_activity] > 50
      recommendations << "High suspicious activity detected. Review security policies."
    end
    
    if results[:inactive_2fa] > 100
      recommendations << "Many users without 2FA. Consider incentivizing 2FA adoption."
    end
    
    recommendations
  end
end

