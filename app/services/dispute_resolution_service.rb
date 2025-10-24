class DisputeResolutionService
  def self.resolve(dispute, resolution_params)
    return false unless can_be_resolved?(dispute)

    dispute.transaction do
      resolution = dispute.build_resolution(resolution_params)

      if resolution.save
        process_resolution(dispute, resolution)
        dispute.update(status: resolution.resolution_type, resolved_at: Time.current)
        create_activity(dispute, :resolved)
        notify_resolution(dispute, resolution)
        true
      else
        dispute.errors.add(:base, "Failed to save resolution: #{resolution.errors.full_messages.join(', ')}")
        false
      end
    end
  end

  private

  def self.can_be_resolved?(dispute)
    dispute.moderator.present? && !dispute.resolved? && !dispute.dismissed? && !dispute.refunded?
  end

  def self.process_resolution(dispute, resolution)
    case resolution.resolution_type
    when 'refunded'
      dispute.escrow_transaction.refund(resolution.refund_amount, admin_approved: true)
    when 'partially_refunded'
      dispute.escrow_transaction.refund(resolution.refund_amount, admin_approved: true)
    when 'resolved'
      dispute.escrow_transaction.release_funds(admin_approved: true)
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

  def self.notify_resolution(dispute, resolution)
    [dispute.buyer, dispute.seller].each do |user|
      DisputeNotificationService.notify(
        user: user,
        title: "Dispute Resolved",
        message: "Your dispute has been resolved. Resolution: #{resolution.notes}",
        resource: dispute
      )
    end
  end
end