class BehavioralAnalysisJob < ApplicationJob
  queue_as :default
  
  # Analyze behavioral patterns for users
  def perform(user_id = nil)
    if user_id
      # Analyze specific user
      user = User.find(user_id)
      analyze_user(user)
    else
      # Analyze users with recent activity
      User.where('updated_at > ?', 7.days.ago).find_each do |user|
        analyze_user(user)
      end
    end
    
    Rails.logger.info "Behavioral analysis completed successfully"
  rescue => e
    Rails.logger.error "Failed to complete behavioral analysis: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end
  
  private
  
  def analyze_user(user)
    # Detect behavioral patterns
    patterns = BehavioralPatternDetector.new(user).detect_all
    
    # Check for anomalies
    anomalous_count = patterns.count { |p| p&.anomalous? }
    
    # Create fraud alert if multiple anomalies detected
    if anomalous_count >= 3
      latest_check = FraudCheck.where(user: user).order(created_at: :desc).first
      
      if latest_check
        FraudAlert.create!(
          fraud_check: latest_check,
          user: user,
          alert_type: :bot_activity,
          severity: :medium,
          title: "Multiple Behavioral Anomalies Detected",
          message: "#{anomalous_count} anomalous patterns detected for user #{user.email}"
        )
      end
    end
  end
end

