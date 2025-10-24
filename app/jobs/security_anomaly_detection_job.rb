class SecurityAnomalyDetectionJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    anomalies = SecurityAnomalyDetector.detect_for(user)
    # Handle anomalies, e.g., notify or log
    anomalies.each do |anomaly|
      Rails.logger.warn("Security anomaly detected for user #{user_id}: #{anomaly}")
      # Optionally, trigger alerts
    end
  end
end