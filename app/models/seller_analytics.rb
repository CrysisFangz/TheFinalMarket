class SellerAnalytics < ApplicationRecord
  # Model for storing daily seller analytics data.
  # Business logic is handled by dedicated services for separation of concerns.
  # Optimized for performance with caching and background processing.

  belongs_to :seller, class_name: 'User'

  validates :date, presence: true
  validates :seller, presence: true
  
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, -> { where('date > ?', 30.days.ago) }
  scope :for_seller, ->(seller) { where(seller: seller) }
  scope :order_by_date_desc, -> { order(date: :desc) }
  
  # Record daily analytics
  def self.record_for_seller(seller, date = Date.current)
    SellerAnalyticsRecorder.call(seller, date).analytics
  end
  
  # Get performance summary
  def self.performance_summary(seller, period = 30)
    SellerPerformanceSummarizer.call(seller, period)
  end
  
  # Get top products
  def self.top_products(seller, limit = 10)
    SellerAnalyticsQueryService.top_products(seller, limit)
  end
  
  # Get sales by category
  def self.sales_by_category(seller, period = 30)
    SellerAnalyticsQueryService.sales_by_category(seller, period)
  end
  
  # Get customer demographics
  def self.customer_demographics(seller)
    SellerAnalyticsQueryService.customer_demographics(seller)
  end
  
  
end

