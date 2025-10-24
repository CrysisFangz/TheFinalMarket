class ReviewInvitationEventService
  attr_reader :invitation

  def initialize(invitation)
    @invitation = invitation
  end

  def publish_created_event
    Rails.logger.debug("Publishing created event for ReviewInvitation ID: #{invitation.id}")
    EventPublisher.publish('review_invitation.created', {
      invitation_id: invitation.id,
      user_id: invitation.user_id,
      order_id: invitation.order_id,
      item_id: invitation.item_id,
      token: invitation.token,
      status: invitation.status,
      expires_at: invitation.expires_at,
      created_at: invitation.created_at
    })
  end

  def publish_updated_event
    Rails.logger.debug("Publishing updated event for ReviewInvitation ID: #{invitation.id}")
    EventPublisher.publish('review_invitation.updated', {
      invitation_id: invitation.id,
      user_id: invitation.user_id,
      order_id: invitation.order_id,
      item_id: invitation.item_id,
      token: invitation.token,
      status: invitation.status,
      expires_at: invitation.expires_at,
      updated_at: invitation.updated_at
    })
  end

  def publish_destroyed_event
    Rails.logger.debug("Publishing destroyed event for ReviewInvitation ID: #{invitation.id}")
    EventPublisher.publish('review_invitation.destroyed', {
      invitation_id: invitation.id,
      user_id: invitation.user_id,
      order_id: invitation.order_id,
      item_id: invitation.item_id,
      token: invitation.token,
      status: invitation.status
    })
  end
end