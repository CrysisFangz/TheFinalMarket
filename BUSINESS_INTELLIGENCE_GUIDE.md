# Business Intelligence & Analytics System - Complete Guide

## Overview

The Final Market's Business Intelligence System provides comprehensive analytics, reporting, and predictive insights to drive data-driven decision making.

---

## Features

### 1. Custom Report Builder

**Report Types:**
- **Revenue Reports** - Daily/weekly/monthly revenue analysis
- **Sales Reports** - Sales performance and conversion metrics
- **Customer Reports** - Customer acquisition, retention, and lifetime value
- **Product Reports** - Product performance and inventory turnover
- **Cohort Reports** - Customer cohort analysis and retention
- **Market Basket Analysis** - Product associations and bundle recommendations

**Report Features:**
- Custom date ranges
- Scheduled execution
- Email delivery
- Auto-export to CSV/JSON
- Public/private sharing
- Cached results

---

### 2. Market Basket Analysis

**Capabilities:**
- Frequent itemset mining
- Association rule generation
- Product affinity calculation
- Bundle recommendations
- Support, confidence, and lift metrics

**Use Cases:**
- Cross-sell recommendations
- Product bundling
- Store layout optimization
- Promotional planning

---

### 3. Predictive Analytics

**Prediction Types:**
- **Customer LTV** - Predict customer lifetime value
- **Churn Prediction** - Identify at-risk customers
- **Demand Forecasting** - Predict product demand
- **Revenue Forecasting** - Forecast future revenue
- **Next Purchase Date** - Predict when customers will buy again

**Features:**
- Confidence scores
- Trend analysis
- Actionable recommendations
- Historical accuracy tracking

---

### 4. Customer Segmentation

**Segment Types:**
- **RFM Segmentation** - Recency, Frequency, Monetary
- **Value-Based** - By customer lifetime value
- **Behavioral** - By user behavior patterns
- **Engagement** - By activity level
- **Custom** - SQL-based custom segments

**Auto-Update:**
- Segments update automatically
- Real-time member tracking
- Segment statistics
- Export capabilities

---

### 5. Analytics Metrics

**Tracked Metrics:**
- Revenue (daily, average order value)
- Orders (total, pending, cancelled)
- Customers (new, active, total)
- Products (sold, unique)
- Traffic (page views, visitors, sessions)
- Conversion (rate, cart abandonment)
- Engagement (time on site, pages per session)
- Retention (customer retention rate)

**Features:**
- Daily metric recording
- Trend analysis
- Growth rate calculation
- Historical data

---

### 6. Dashboard Widgets

**Widget Types:**
- Revenue Chart
- Sales Chart
- Customer Chart
- Conversion Funnel
- Top Products
- Recent Orders
- Customer Segments
- Key Metrics

**Customization:**
- Drag-and-drop positioning
- Configurable size
- Custom time ranges
- Real-time updates

---

## Usage

### Creating Reports

```ruby
# Create a revenue report
report = AnalyticsReport.create!(
  user: current_user,
  name: 'Monthly Revenue Report',
  description: 'Monthly revenue breakdown',
  report_type: :revenue_report,
  category: :finance,
  configuration: {
    refresh_interval: 3600,
    email_recipients: ['admin@example.com']
  },
  scheduled: true,
  active: true
)

# Execute report
result = report.execute(
  start_date: 30.days.ago.to_date,
  end_date: Date.current
)

# Access results
result[:summary] # => { total_revenue: "$12,345.67", ... }
result[:data] # => { daily_revenue: {...}, ... }
result[:visualizations] # => [{ type: 'line_chart', ... }]

# Get cached result
cached = report.cached_result
```

### Market Basket Analysis

```ruby
# Create market basket report
report = AnalyticsReport.create!(
  user: current_user,
  name: 'Product Associations',
  report_type: :market_basket,
  category: :product,
  configuration: {
    min_support: 0.01,
    min_confidence: 0.3
  }
)

# Execute analysis
result = report.execute(
  start_date: 90.days.ago.to_date,
  end_date: Date.current
)

# Access association rules
rules = result[:data][:association_rules]
# => [
#   { antecedent: "Product A", consequent: "Product B", 
#     support: 0.05, confidence: 0.75, lift: 2.5 },
#   ...
# ]

# Get bundle recommendations
bundles = result[:data][:bundle_recommendations]
# => { "Product A" => { items: ["B", "C"], avg_lift: 2.3 }, ... }
```

### Predictive Analytics

```ruby
# Predict customer LTV
ltv = PredictiveAnalyticsService.predict_customer_ltv(user)
# => {
#   predicted_ltv: 1250.50,
#   avg_order_value: 125.00,
#   purchase_frequency: 2.5,
#   predicted_lifespan_months: 24,
#   confidence: 78.5
# }

# Predict churn
churn = PredictiveAnalyticsService.predict_churn(user)
# => {
#   churn_probability: 0.65,
#   risk_level: 'medium',
#   days_since_last_order: 45,
#   avg_days_between_orders: 30.5,
#   recommended_action: 'Send re-engagement email...'
# }

# Predict next purchase
next_purchase = PredictiveAnalyticsService.predict_next_purchase(user)
# => {
#   predicted_date: Date.new(2025, 11, 15),
#   confidence_interval: { lower: ..., upper: ... },
#   avg_days_between_orders: 30.5,
#   confidence: 82.3
# }

# Forecast product demand
demand = PredictiveAnalyticsService.predict_product_demand(product, 30)
# => {
#   predicted_demand: 150,
#   predicted_daily_demand: 5.0,
#   current_avg_daily_sales: 4.2,
#   trend: 'increasing',
#   confidence: 75.8
# }

# Forecast revenue
forecast = PredictiveAnalyticsService.forecast_revenue(30)
# => {
#   forecasted_revenue: 45000.00,
#   forecasted_daily_revenue: [1500, 1520, ...],
#   current_avg_daily_revenue: 1450.00,
#   trend: 'increasing',
#   growth_rate: 3.5,
#   confidence: 80.2
# }
```

### Customer Segmentation

```ruby
# Create RFM segment
segment = CustomerSegment.create!(
  name: 'VIP Customers',
  description: 'High-value repeat customers',
  segment_type: :rfm,
  criteria: {
    recency_days: 90,
    min_frequency: 5,
    min_monetary: 50000 # in cents
  },
  auto_update: true,
  active: true
)

# Update segment members
segment.update_members!

# Get segment statistics
stats = segment.statistics
# => {
#   member_count: 125,
#   total_revenue: 156250.00,
#   avg_order_value: 125.00,
#   total_orders: 1250,
#   avg_orders_per_customer: 10.0
# }

# Access segment members
segment.users.each do |user|
  puts "#{user.name}: #{user.orders.count} orders"
end
```

### Analytics Metrics

```ruby
# Record a metric
AnalyticsMetric.record('daily_revenue', 5432.10, :revenue, Date.current)

# Get metric value
value = AnalyticsMetric.value_for('daily_revenue', Date.current)
# => 5432.10

# Get metric trend
trend = AnalyticsMetric.trend('daily_revenue', 30)
# => [[Date.new(2025, 10, 1), 5000], [Date.new(2025, 10, 2), 5200], ...]

# Calculate growth rate
growth = AnalyticsMetric.growth_rate('daily_revenue', 7)
# => 12.5 (12.5% growth over 7 days)
```

### Dashboard Widgets

```ruby
# Create widget
widget = DashboardWidget.create!(
  user: current_user,
  widget_type: 'revenue_chart',
  title: 'Revenue Trend',
  configuration: { days: 30 },
  position: 0,
  width: 6,
  height: 4,
  visible: true
)

# Get widget data
data = widget.data
# => { "2025-10-01" => 5000, "2025-10-02" => 5200, ... }
```

### Data Exports

```ruby
# Create export
export = DataExport.create!(
  user: current_user,
  export_type: 'revenue',
  parameters: {
    start_date: 30.days.ago,
    end_date: Date.current
  },
  status: :pending,
  expires_at: 7.days.from_now
)

# Process export (in background job)
# ... generate file ...

export.update!(
  file_name: 'revenue_export.csv',
  file_path: '/path/to/file.csv',
  file_size_bytes: 12345,
  record_count: 1000,
  status: :completed,
  completed_at: Time.current
)

# Check if ready
export.ready? # => true

# Get download URL
url = export.download_url
# => "/downloads/exports/123/revenue_export.csv"
```

---

## Background Jobs

### Analytics Metrics Job

Runs daily to record metrics:

```ruby
# Manual execution
AnalyticsMetricsJob.perform_now(Date.current)

# Scheduled execution (daily at 1:00 AM)
# Configured in config/schedule.yml
```

### Customer Segment Update Job

Updates customer segments:

```ruby
# Update all auto-update segments
CustomerSegmentUpdateJob.perform_now

# Update specific segment
CustomerSegmentUpdateJob.perform_now(segment.id)

# Scheduled execution (daily at 4:00 AM)
```

### Scheduled Report Job

Executes scheduled reports:

```ruby
# Execute report
ScheduledReportJob.perform_now(report.id, { start_date: 7.days.ago })

# Configured per report schedule
```

### Data Export Cleanup Job

Cleans up expired exports:

```ruby
# Manual cleanup
DataExportCleanupJob.perform_now

# Scheduled execution (weekly on Sunday at 5:00 AM)
```

---

## API Integration

### Report Execution API

```ruby
# POST /api/reports/:id/execute
{
  "start_date": "2025-09-01",
  "end_date": "2025-09-30"
}

# Response
{
  "report_name": "Monthly Revenue Report",
  "generated_at": "2025-10-07T10:00:00Z",
  "summary": {
    "total_revenue": "$12,345.67",
    "total_orders": 250,
    "avg_order_value": "$49.38"
  },
  "data": { ... },
  "visualizations": [ ... ]
}
```

### Metrics API

```ruby
# GET /api/metrics/:metric_name
{
  "metric_name": "daily_revenue",
  "period": "30d",
  "data": [
    { "date": "2025-10-01", "value": 5000 },
    { "date": "2025-10-02", "value": 5200 }
  ],
  "growth_rate": 12.5
}
```

### Predictions API

```ruby
# POST /api/predictions/ltv
{
  "user_id": 123
}

# Response
{
  "predicted_ltv": 1250.50,
  "confidence": 78.5,
  "factors": { ... }
}
```

---

## Best Practices

### For Analysts

1. **Use appropriate date ranges** for meaningful insights
2. **Schedule reports** for regular delivery
3. **Cache results** to improve performance
4. **Export data** for deeper analysis
5. **Monitor trends** over time
6. **Segment customers** for targeted campaigns
7. **Validate predictions** against actual outcomes

### For Developers

1. **Index database columns** used in reports
2. **Use background jobs** for heavy computations
3. **Cache expensive queries**
4. **Paginate large result sets**
5. **Monitor job performance**
6. **Handle errors gracefully**
7. **Test report accuracy**

### For Business Users

1. **Review dashboards** daily
2. **Act on predictions** promptly
3. **Test hypotheses** with A/B testing
4. **Share insights** with team
5. **Track KPIs** consistently
6. **Investigate anomalies**
7. **Document decisions**

---

## Troubleshooting

### Reports Taking Too Long

**Solutions:**
1. Reduce date range
2. Add database indexes
3. Use cached results
4. Move to background job
5. Optimize queries

### Inaccurate Predictions

**Solutions:**
1. Retrain models with more data
2. Adjust confidence thresholds
3. Validate input data quality
4. Review model parameters
5. Check for data anomalies

### Segment Not Updating

**Solutions:**
1. Check segment criteria
2. Verify auto_update is enabled
3. Run update job manually
4. Check for SQL errors
5. Review logs

---

**Business Intelligence System v1.0**
Developed for The Final Market
Built with Ruby on Rails 8.0

