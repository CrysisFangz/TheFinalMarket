class DisputeInitiationService
  def self.initiate_dispute(escrow_transaction)
    return false if escrow_transaction.disputed?

    escrow_transaction.transaction do
      escrow_transaction.update(status: :disputed)
      dispute = escrow_transaction.order.create_dispute!(
        buyer: escrow_transaction.sender,
        seller: escrow_transaction.receiver,
        amount: escrow_transaction.amount,
        escrow_transaction: escrow_transaction
      )
      notify_parties(escrow_transaction, "Dispute initiated")
      DisputeAssignmentService.new(dispute).assign_mediator
    end
    true
  rescue => e
    escrow_transaction.errors.add(:base, "Failed to initiate dispute: #{e.message}")
    false
  end

  private

  def self.notify_parties(escrow_transaction, message)
    [escrow_transaction.sender, escrow_transaction.receiver].each do |user|
      EscrowNotificationService.notify(
        user: user,
        title: "Escrow Dispute",
        message: message,
        resource: escrow_transaction
      )
    end
  end
end