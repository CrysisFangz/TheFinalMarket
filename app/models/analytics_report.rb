class AnalyticsReport < ApplicationRecord
  belongs_to :user
  has_many :report_schedules, dependent: :destroy
  has_many :report_executions, dependent: :destroy
  
  validates :name, presence: true
  validates :report_type, presence: true
  
  scope :active, -> { where(active: true) }
  scope :scheduled, -> { where(scheduled: true) }
  scope :public_reports, -> { where(is_public: true) }
  scope :by_category, ->(category) { where(category: category) }
  
  # Report types
  enum report_type: {
    sales_report: 0,
    revenue_report: 1,
    customer_report: 2,
    product_report: 3,
    traffic_report: 4,
    conversion_report: 5,
    cohort_report: 6,
    market_basket: 7,
    custom_query: 9
  }
  
  # Report categories
  enum category: {
    sales: 0,
    marketing: 1,
    operations: 2,
    finance: 3,
    customer: 4,
    product: 5
  }
  
  # Execute report
  def execute(params = {})
    execution = report_executions.create!(
      executed_at: Time.current,
      parameters: params,
      status: :running
    )
    
    begin
      result = case report_type.to_sym
      when :sales_report
        AnalyticsEngine::SalesReport.new(self, params).generate
      when :revenue_report
        AnalyticsEngine::RevenueReport.new(self, params).generate
      when :customer_report
        AnalyticsEngine::CustomerReport.new(self, params).generate
      when :product_report
        AnalyticsEngine::ProductReport.new(self, params).generate
      when :cohort_report
        AnalyticsEngine::CohortReport.new(self, params).generate
      when :market_basket
        AnalyticsEngine::MarketBasketReport.new(self, params).generate
      when :custom_query
        AnalyticsEngine::CustomQueryReport.new(self, params).generate
      else
        { error: "Unknown report type" }
      end
      
      execution.update!(
        status: :completed,
        result_data: result,
        completed_at: Time.current
      )
      
      result
    rescue => e
      execution.update!(
        status: :failed,
        error_message: e.message,
        completed_at: Time.current
      )
      
      raise e
    end
  end
  
  # Get last execution
  def last_execution
    report_executions.order(executed_at: :desc).first
  end
  
  # Check if report is stale
  def stale?
    return true unless last_execution
    
    refresh_interval = configuration['refresh_interval'] || 3600
    last_execution.executed_at < refresh_interval.seconds.ago
  end
  
  # Get cached result or execute
  def cached_result(params = {})
    if stale? || params.present?
      execute(params)
    else
      last_execution.result_data
    end
  end
end

