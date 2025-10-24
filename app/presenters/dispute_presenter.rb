class DisputePresenter
  def initialize(dispute)
    @dispute = dispute
  end

  def as_json(options = {})
    {
      id: @dispute.id,
      order_id: @dispute.order_id,
      buyer_id: @dispute.buyer_id,
      seller_id: @dispute.seller_id,
      moderator_id: @dispute.moderator_id,
      escrow_transaction_id: @dispute.escrow_transaction_id,
      title: @dispute.title,
      description: @dispute.description,
      amount: @dispute.amount,
      status: @dispute.status,
      dispute_type: @dispute.dispute_type,
      moderator_assigned_at: @dispute.moderator_assigned_at,
      resolved_at: @dispute.resolved_at,
      created_at: @dispute.created_at,
      updated_at: @dispute.updated_at,
      can_participate: @dispute.can_participate?(options[:current_user]),
      comments_count: @dispute.comments.count,
      evidences_count: @dispute.evidences.count,
      resolution: @dispute.resolution&.as_json
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end