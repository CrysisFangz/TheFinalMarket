class ReviewInvitationManagementService
  attr_reader :invitation

  def initialize(invitation)
    @invitation = invitation
  end

  def expire!
    Rails.logger.info("Expiring ReviewInvitation ID: #{invitation.id}")
    ReviewInvitationService.expire_invitation(invitation)
    Rails.logger.info("ReviewInvitation ID: #{invitation.id} expired successfully")
  end

  def complete!
    Rails.logger.info("Completing ReviewInvitation ID: #{invitation.id}")
    ReviewInvitationService.complete_invitation(invitation)
    Rails.logger.info("ReviewInvitation ID: #{invitation.id} completed successfully")
  end

  def set_defaults
    Rails.logger.debug("Setting defaults for ReviewInvitation ID: #{invitation.id}")
    invitation.token = generate_unique_token
    invitation.expires_at ||= 30.days.from_now
    invitation.status ||= :pending
  end

  private

  def generate_unique_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless ReviewInvitation.exists?(token: token)
    end
  end
end