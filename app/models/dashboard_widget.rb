class DashboardWidget < ApplicationRecord
  include CircuitBreaker

  belongs_to :user

  validates :widget_type, presence: true
  validates :title, presence: true

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position) }

  WIDGET_TYPES = %w[
    revenue_chart
    sales_chart
    customer_chart
    product_chart
    conversion_funnel
    top_products
    recent_orders
    customer_segments
    key_metrics
    cohort_heatmap
  ].freeze

  validates :widget_type, inclusion: { in: WIDGET_TYPES }

  after_create :publish_created_event
  after_update :publish_updated_event

  def data
    Rails.cache.fetch("widget:#{id}:data", expires_in: 5.minutes) do
      with_retry do
        self.class.with_circuit_breaker(name: 'dashboard_service') do
          raw_data = Dashboard::WidgetDataService.fetch_data(self)
          Dashboard::WidgetDataPresenter.present(raw_data, widget_type)
        end
      end
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('dashboard_widget.created', { widget_id: id, title: title })
  end

  def publish_updated_event
    EventPublisher.publish('dashboard_widget.updated', { widget_id: id, title: title })
  end

  def with_retry(max_retries: 3, &block)
    retries = 0
    begin
      yield
    rescue StandardError => e
      retries += 1
      retry if retries < max_retries
      Rails.logger.error("Failed after #{retries} retries: #{e.message}")
      raise e
    end
  end
end

