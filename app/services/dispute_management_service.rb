class DisputeManagementService
  def self.assign_to_moderator(dispute, moderator)
    return false unless moderator.can_moderate_disputes?

    dispute.transaction do
      dispute.update(
        moderator: moderator,
        status: :under_review,
        moderator_assigned_at: Time.current
      )

      notify_parties_of_moderator_assignment(dispute)
      create_activity(dispute, :moderator_assigned)
    end
  end

  def self.freeze_escrow_transaction(dispute)
    dispute.escrow_transaction&.update(status: :disputed)
  end

  private

  def self.notify_parties_of_moderator_assignment(dispute)
    [dispute.buyer, dispute.seller].each do |user|
      DisputeNotificationService.notify(
        user: user,
        title: "Moderator Assigned",
        message: "A moderator has been assigned to your dispute",
        resource: dispute
      )
    end
  end

  def self.create_activity(dispute, action, user: nil)
    DisputeActivity.create!(
      dispute: dispute,
      user: user || dispute.moderator,
      action: action,
      data: {
        status: dispute.status,
        resolution_type: dispute.resolution&.resolution_type,
        refund_amount: dispute.resolution&.refund_amount
      }
    )
  end
end