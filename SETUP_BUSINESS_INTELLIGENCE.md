# Business Intelligence System - Setup Guide

## Quick Start

Follow these steps to set up the Business Intelligence system:

### 1. Run Database Migrations

```bash
bin/rails db:migrate
```

This will create:
- `analytics_reports` table
- `report_executions` table
- `analytics_metrics` table
- `customer_segments` table
- `customer_segment_members` table
- `dashboard_widgets` table
- `data_exports` table
- `predictive_models` table
- `predictions` table

### 2. Load Seed Data

```bash
bin/rails runner "load Rails.root.join('db/seeds/business_intelligence_seeds.rb')"
```

This will create:
- 6 sample analytics reports
- 6 customer segments
- 30 days of sample metrics
- 4 predictive models

### 3. Set Up Scheduled Jobs

Jobs are already configured in `config/schedule.yml`:

```yaml
analytics_metrics:
  cron: "0 1 * * *"  # Daily at 1:00 AM
  
customer_segment_update:
  cron: "0 4 * * *"  # Daily at 4:00 AM
  
data_export_cleanup:
  cron: "0 5 * * 0"  # Every Sunday at 5:00 AM
```

Load the schedule:

```bash
# If using Sidekiq Cron
Sidekiq::Cron::Job.load_from_hash YAML.load_file('config/schedule.yml')

# If using whenever
whenever --update-crontab
```

### 4. Test the System

```bash
# Start Rails console
bin/rails console

# Test report execution
report = AnalyticsReport.first
result = report.execute(start_date: 30.days.ago.to_date, end_date: Date.current)
puts result[:summary]

# Test customer segmentation
segment = CustomerSegment.first
segment.update_members!
puts "Segment has #{segment.member_count} members"

# Test predictive analytics
user = User.first
ltv = PredictiveAnalyticsService.predict_customer_ltv(user)
puts "Predicted LTV: $#{ltv[:predicted_ltv]}"

# Test metrics
AnalyticsMetricsJob.perform_now(Date.current)
trend = AnalyticsMetric.trend('daily_revenue', 7)
puts "Revenue trend: #{trend}"
```

---

## Integration Steps

### Step 1: Add Analytics to Controllers

#### Track Page Views

```ruby
class ProductsController < ApplicationController
  after_action :track_page_view, only: [:show]
  
  private
  
  def track_page_view
    # Track product view
    # This would integrate with analytics service
  end
end
```

#### Track Conversions

```ruby
class OrdersController < ApplicationController
  def create
    @order = current_user.orders.build(order_params)
    
    if @order.save
      # Track conversion
      AnalyticsMetric.record(
        'conversion',
        1,
        :conversion,
        Date.current
      )
      
      redirect_to order_path(@order)
    end
  end
end
```

### Step 2: Add Dashboard Widgets

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @widgets = current_user.dashboard_widgets.visible.ordered
  end
  
  def add_widget
    widget = current_user.dashboard_widgets.create!(widget_params)
    redirect_to dashboard_path
  end
  
  private
  
  def widget_params
    params.require(:dashboard_widget).permit(
      :widget_type, :title, :width, :height, :position, configuration: {}
    )
  end
end
```

```erb
<!-- app/views/dashboard/index.html.erb -->
<div class="dashboard">
  <% @widgets.each do |widget| %>
    <div class="widget" style="width: <%= widget.width %>; height: <%= widget.height %>;">
      <h3><%= widget.title %></h3>
      <div class="widget-content">
        <%= render "widgets/#{widget.widget_type}", data: widget.data %>
      </div>
    </div>
  <% end %>
</div>
```

### Step 3: Add Report Builder UI

```ruby
# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  def index
    @reports = current_user.analytics_reports.active
  end
  
  def show
    @report = current_user.analytics_reports.find(params[:id])
    @result = @report.cached_result
  end
  
  def create
    @report = current_user.analytics_reports.build(report_params)
    
    if @report.save
      redirect_to report_path(@report)
    else
      render :new
    end
  end
  
  def execute
    @report = current_user.analytics_reports.find(params[:id])
    @result = @report.execute(execution_params)
    
    render json: @result
  end
  
  private
  
  def report_params
    params.require(:analytics_report).permit(
      :name, :description, :report_type, :category,
      :scheduled, :is_public, configuration: {}, filters: {}
    )
  end
  
  def execution_params
    params.permit(:start_date, :end_date)
  end
end
```

### Step 4: Add Customer Segmentation UI

```ruby
# app/controllers/segments_controller.rb
class SegmentsController < ApplicationController
  def index
    @segments = CustomerSegment.active
  end
  
  def show
    @segment = CustomerSegment.find(params[:id])
    @members = @segment.users.page(params[:page])
    @statistics = @segment.statistics
  end
  
  def create
    @segment = CustomerSegment.new(segment_params)
    
    if @segment.save
      @segment.update_members!
      redirect_to segment_path(@segment)
    else
      render :new
    end
  end
  
  def update_members
    @segment = CustomerSegment.find(params[:id])
    @segment.update_members!
    
    redirect_to segment_path(@segment), notice: 'Segment updated'
  end
  
  private
  
  def segment_params
    params.require(:customer_segment).permit(
      :name, :description, :segment_type, :auto_update, criteria: {}
    )
  end
end
```

### Step 5: Add Predictive Analytics UI

```ruby
# app/controllers/predictions_controller.rb
class PredictionsController < ApplicationController
  def customer_ltv
    @user = User.find(params[:user_id])
    @prediction = PredictiveAnalyticsService.predict_customer_ltv(@user)
    
    render json: @prediction
  end
  
  def churn_risk
    @user = User.find(params[:user_id])
    @prediction = PredictiveAnalyticsService.predict_churn(@user)
    
    render json: @prediction
  end
  
  def demand_forecast
    @product = Product.find(params[:product_id])
    days_ahead = params[:days_ahead]&.to_i || 30
    @prediction = PredictiveAnalyticsService.predict_product_demand(@product, days_ahead)
    
    render json: @prediction
  end
  
  def revenue_forecast
    days_ahead = params[:days_ahead]&.to_i || 30
    @prediction = PredictiveAnalyticsService.forecast_revenue(days_ahead)
    
    render json: @prediction
  end
end
```

---

## Configuration

### Customize Report Settings

Create `config/initializers/business_intelligence.rb`:

```ruby
# Business Intelligence Configuration
BUSINESS_INTELLIGENCE_CONFIG = {
  # Report settings
  default_refresh_interval: 3600, # 1 hour
  max_report_execution_time: 300, # 5 minutes
  
  # Market basket analysis
  default_min_support: 0.01,
  default_min_confidence: 0.3,
  
  # Predictive analytics
  ltv_prediction_enabled: true,
  churn_prediction_enabled: true,
  demand_forecast_enabled: true,
  
  # Customer segmentation
  auto_update_segments: true,
  segment_update_frequency: 1.day,
  
  # Data exports
  export_retention_days: 7,
  max_export_size_mb: 100,
  
  # Metrics
  metric_retention_days: 365
}.freeze
```

### Add Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Analytics Reports
  resources :reports do
    member do
      post :execute
      get :download
    end
  end
  
  # Customer Segments
  resources :segments do
    member do
      post :update_members
      get :export
    end
  end
  
  # Dashboard
  get 'dashboard', to: 'dashboard#index'
  resources :dashboard_widgets, only: [:create, :update, :destroy]
  
  # Predictions API
  namespace :api do
    namespace :predictions do
      post :customer_ltv
      post :churn_risk
      post :demand_forecast
      post :revenue_forecast
    end
    
    resources :metrics, only: [:index, :show]
  end
  
  # Data Exports
  resources :data_exports, only: [:index, :create, :show] do
    member do
      get :download
    end
  end
end
```

---

## Testing

### Unit Tests

```ruby
# test/services/predictive_analytics_service_test.rb
require 'test_helper'

class PredictiveAnalyticsServiceTest < ActiveSupport::TestCase
  test "predicts customer LTV" do
    user = users(:active_customer)
    result = PredictiveAnalyticsService.predict_customer_ltv(user)
    
    assert result[:predicted_ltv] > 0
    assert result[:confidence] > 0
    assert result[:confidence] <= 100
  end
  
  test "predicts churn risk" do
    user = users(:at_risk_customer)
    result = PredictiveAnalyticsService.predict_churn(user)
    
    assert_includes ['very_low', 'low', 'medium', 'high'], result[:risk_level]
    assert result[:churn_probability] >= 0
    assert result[:churn_probability] <= 1
  end
end
```

### Integration Tests

```ruby
# test/integration/reports_test.rb
require 'test_helper'

class ReportsTest < ActionDispatch::IntegrationTest
  test "executes revenue report" do
    user = users(:admin)
    sign_in user
    
    report = analytics_reports(:revenue_report)
    
    post execute_report_path(report), params: {
      start_date: 30.days.ago.to_date,
      end_date: Date.current
    }
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json['summary'].present?
    assert json['data'].present?
  end
end
```

---

## Monitoring

### Key Metrics to Track

1. **Report Performance**
   - Execution time
   - Success rate
   - Cache hit rate

2. **Segment Health**
   - Member count trends
   - Update frequency
   - Segment overlap

3. **Prediction Accuracy**
   - Actual vs predicted
   - Confidence distribution
   - Model performance

4. **System Performance**
   - Job queue length
   - Database query time
   - Memory usage

### Dashboard Queries

```ruby
# Report execution stats
ReportExecution.where('executed_at > ?', 7.days.ago)
               .group(:status)
               .count

# Average execution time
ReportExecution.completed
               .where('executed_at > ?', 7.days.ago)
               .average(:execution_time_ms)

# Segment member counts
CustomerSegment.active.pluck(:name, :member_count).to_h

# Prediction accuracy
PredictiveModel.active.pluck(:model_name, :accuracy).to_h
```

---

## Troubleshooting

### Issue: Reports timing out

**Solutions:**
1. Add database indexes
2. Reduce date range
3. Use background jobs
4. Optimize queries
5. Increase timeout limit

### Issue: Segments not updating

**Solutions:**
1. Check scheduled jobs
2. Verify criteria syntax
3. Run update manually
4. Check database locks
5. Review error logs

### Issue: Predictions inaccurate

**Solutions:**
1. Retrain models
2. Add more historical data
3. Adjust parameters
4. Validate input data
5. Review algorithm

---

## Next Steps

1. ✅ Run migrations
2. ✅ Load seed data
3. ✅ Set up scheduled jobs
4. ✅ Test the system
5. 📝 Add UI components
6. 📝 Configure routes
7. 📝 Customize settings
8. 📝 Set up monitoring
9. 📝 Train team
10. 📝 Deploy to production

---

**Business Intelligence System v1.0**
Setup Guide for The Final Market

