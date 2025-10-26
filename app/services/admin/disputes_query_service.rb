# frozen_string_literal: true

class Admin::DisputesQueryService
  def fetch_disputes(page)
    Dispute.includes(:buyer, :seller, :moderator).order(created_at: :desc).page(page)
  end

  def fetch_dispute_comments(dispute)
    dispute.dispute_comments.includes(:user).order(created_at: :asc)
  end
end