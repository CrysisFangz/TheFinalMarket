class TrustScoreUpdateJob < ApplicationJob
  queue_as :default
  
  # Update trust scores for all active users
  def perform(user_id = nil)
    if user_id
      # Update specific user
      user = User.find(user_id)
      update_trust_score(user)
    else
      # Update all users who have been active in last 30 days
      User.where('updated_at > ?', 30.days.ago).find_each do |user|
        update_trust_score(user)
      end
    end
    
    Rails.logger.info "Trust scores updated successfully"
  rescue => e
    Rails.logger.error "Failed to update trust scores: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end
  
  private
  
  def update_trust_score(user)
    trust_score = TrustScore.calculate_for(user)
    
    # Update user's trust score
    user.update!(trust_score: trust_score.score)
    
    # Send notification if score changed significantly
    previous = user.trust_scores.where('created_at < ?', trust_score.created_at)
                   .order(created_at: :desc)
                   .first
    
    if previous && (trust_score.score - previous.score).abs >= 20
      TrustScoreMailer.score_changed(user, trust_score, previous).deliver_later
    end
  end
end

