class SecurityRecommender
  def self.recommendations_for(user)
    cache_key = "security_recommendations_user_#{user.id}_#{user.updated_at.to_i}_#{SecurityAudit.where(user: user).maximum(:updated_at).to_i}"

    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      recommendations = []

      unless user.two_factor_authentications.active.any?
        recommendations << build_recommendation('high', 'Enable Two-Factor Authentication', 'Add an extra layer of security to your account', 'enable_2fa')
      end

      unless user.identity_verified?
        recommendations << build_recommendation('medium', 'Verify Your Identity', 'Increase trust and unlock premium features', 'verify_identity')
      end

      if user.password_changed_at && user.password_changed_at < 90.days.ago
        recommendations << build_recommendation('medium', 'Update Your Password', "Your password hasn't been changed in 90 days", 'change_password')
      end

      recent_failures = SecurityAudit.where(user: user, event_type: :login_failure)
                                    .where('created_at > ?', 7.days.ago)
                                    .count

      if recent_failures > 5
        recommendations << build_recommendation('high', 'Review Recent Login Attempts', "#{recent_failures} failed login attempts in the past week", 'review_activity')
      end

      recommendations
    end
  rescue => e
    Rails.logger.error("Error generating security recommendations: #{e.message}")
    []
  end

  private

  def self.build_recommendation(priority, title, description, action)
    {
      priority: priority,
      title: title,
      description: description,
      action: action
    }
  end
end