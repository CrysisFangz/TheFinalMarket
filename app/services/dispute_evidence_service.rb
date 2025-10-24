class DisputeEvidenceService
  def self.add_evidence(dispute, user, evidence_params)
    return false unless dispute.can_participate?(user)

    evidence = dispute.evidences.create(
      user: user,
      title: evidence_params[:title],
      description: evidence_params[:description],
      attachment: evidence_params[:attachment]
    )

    if evidence.persisted?
      create_activity(dispute, :evidence_added, user: user)
      notify_evidence_added(dispute, evidence)
      true
    else
      false
    end
  end

  private

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

  def self.notify_evidence_added(dispute, evidence)
    [dispute.buyer, dispute.seller, dispute.moderator].compact.each do |user|
      next if user.id == evidence.user_id

      DisputeNotificationService.notify(
        user: user,
        title: "New Evidence Added",
        message: "New evidence has been added to the dispute",
        resource: evidence
      )
    end
  end
end