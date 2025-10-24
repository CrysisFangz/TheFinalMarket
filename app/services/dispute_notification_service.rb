class DisputeNotificationService
  def self.notify(user:, title:, message:, resource:)
    NotificationService.notify(
      user: user,
      title: title,
      message: message,
      resource: resource
    )
  end

  def self.notify_parties(dispute)
    [dispute.buyer, dispute.seller].each do |user|
      notify(
        user: user,
        title: "Dispute Opened",
        message: "A dispute has been opened for order ##{dispute.order.id}",
        resource: dispute
      )
    end
  end

  def self.notify_status_change(dispute)
    [dispute.buyer, dispute.seller, dispute.moderator].compact.each do |user|
      notify(
        user: user,
        title: "Dispute Status Updated",
        message: "Dispute status changed to: #{dispute.status}",
        resource: dispute
      )
    end
  end
end