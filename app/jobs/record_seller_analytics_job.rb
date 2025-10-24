class RecordSellerAnalyticsJob < ApplicationJob
  queue_as :analytics

  def perform(seller_id, date = Date.current)
    seller = User.find(seller_id)
    SellerAnalyticsRecorder.call(seller, date)
  rescue ActiveRecord::RecordNotFound
    # Handle if seller not found
  end
end