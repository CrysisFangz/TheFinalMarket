require 'admin/disputes_query_service'

class Admin::DisputesController < Admin::BaseController
  before_action :set_dispute, only: [:show, :assign_moderator, :post_comment, :resolve]

  def index
    @disputes = Admin::DisputesQueryService.new.fetch_disputes(params[:page])
  rescue => e
    Rails.logger.error("Disputes index failed: #{e.message}")
    @disputes = Dispute.none
    flash[:error] = 'Unable to load disputes.'
  end

  def show
    @dispute_comments = Admin::DisputesQueryService.new.fetch_dispute_comments(@dispute)
  rescue => e
    Rails.logger.error("Dispute show failed: #{e.message}")
    @dispute_comments = DisputeComment.none
    flash[:error] = 'Unable to load dispute comments.'
  end

  def assign_moderator
    moderator = CircuitBreaker.execute_with_fallback(:user_find) do
      User.find(params[:moderator_id])
    end
    if @dispute.update(moderator: moderator, status: :under_review)
      redirect_to admin_dispute_path(@dispute), notice: "Moderator assigned successfully."
    else
      redirect_to admin_dispute_path(@dispute), alert: "Failed to assign moderator."
    end
  rescue => e
    Rails.logger.error("Assign moderator failed: #{e.message}")
    redirect_to admin_dispute_path(@dispute), alert: "Failed to assign moderator."
  end

  def post_comment
    @comment = CircuitBreaker.execute_with_fallback(:dispute_comment_create) do
      @dispute.dispute_comments.new(comment_params.merge(user: current_user))
    end
    if @comment.save
      redirect_to admin_dispute_path(@dispute), notice: "Comment posted successfully."
    else
      render :show
    end
  rescue => e
    Rails.logger.error("Post comment failed: #{e.message}")
    redirect_to admin_dispute_path(@dispute), alert: "Failed to post comment."
  end

  def resolve
    resolution = params.dig(:dispute, :resolution)
    result = CircuitBreaker.execute_with_fallback(:dispute_resolve) do
      DisputeResolutionService.new(@dispute, current_user).resolve(resolution)
    end
    if result
      redirect_to admin_dispute_path(@dispute), notice: "Dispute has been resolved."
    else
      redirect_to admin_dispute_path(@dispute), alert: "Failed to resolve dispute."
    end
  rescue => e
    Rails.logger.error("Resolve dispute failed: #{e.message}")
    redirect_to admin_dispute_path(@dispute), alert: "Failed to resolve dispute."
  end

  private

  def set_dispute
    @dispute = CircuitBreaker.execute_with_fallback(:dispute_find) do
      Dispute.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("Admin attempted to access non-existent dispute: #{params[:id]}")
    redirect_to admin_disputes_path, alert: 'Dispute not found.'
  end

  def comment_params
    params.require(:dispute_comment).permit(:body)
  end
end
