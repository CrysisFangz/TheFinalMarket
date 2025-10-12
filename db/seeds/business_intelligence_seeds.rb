puts "🎯 Seeding Business Intelligence System..."

# Create sample analytics reports
admin_user = User.first || User.create!(
  email: 'admin@example.com',
  password: 'password',
  name: 'Admin User'
)

puts "Creating analytics reports..."

reports = [
  {
    name: 'Daily Revenue Report',
    description: 'Daily revenue breakdown with trends and comparisons',
    report_type: :revenue_report,
    category: :finance,
    configuration: {
      refresh_interval: 3600,
      email_recipients: ['admin@example.com'],
      auto_export: false
    },
    scheduled: true,
    is_public: false
  },
  {
    name: 'Weekly Sales Summary',
    description: 'Weekly sales performance and conversion metrics',
    report_type: :sales_report,
    category: :sales,
    configuration: {
      refresh_interval: 86400,
      email_recipients: ['sales@example.com']
    },
    scheduled: true,
    is_public: false
  },
  {
    name: 'Customer Cohort Analysis',
    description: 'Customer retention and cohort performance',
    report_type: :cohort_report,
    category: :customer,
    configuration: {
      refresh_interval: 86400,
      cohort_period: 'month'
    },
    scheduled: true,
    is_public: false
  },
  {
    name: 'Market Basket Analysis',
    description: 'Product associations and bundle recommendations',
    report_type: :market_basket,
    category: :product,
    configuration: {
      refresh_interval: 86400,
      min_support: 0.01,
      min_confidence: 0.3
    },
    scheduled: true,
    is_public: false
  },
  {
    name: 'Customer Insights',
    description: 'Customer acquisition, segmentation, and lifetime value',
    report_type: :customer_report,
    category: :customer,
    configuration: {
      refresh_interval: 3600
    },
    scheduled: true,
    is_public: true
  },
  {
    name: 'Product Performance',
    description: 'Top products, inventory turnover, and trends',
    report_type: :product_report,
    category: :product,
    configuration: {
      refresh_interval: 3600
    },
    scheduled: true,
    is_public: true
  }
]

reports.each do |report_data|
  AnalyticsReport.find_or_create_by!(
    user: admin_user,
    name: report_data[:name]
  ) do |report|
    report.description = report_data[:description]
    report.report_type = report_data[:report_type]
    report.category = report_data[:category]
    report.configuration = report_data[:configuration]
    report.scheduled = report_data[:scheduled]
    report.is_public = report_data[:is_public]
    report.active = true
  end
end

puts "✅ Created #{AnalyticsReport.count} analytics reports"

# Create customer segments
puts "Creating customer segments..."

segments = [
  {
    name: 'High Value Customers',
    description: 'Customers with lifetime value > $1000',
    segment_type: :value_based,
    criteria: { min_value: 100000 }, # in cents
    auto_update: true
  },
  {
    name: 'VIP Customers',
    description: 'Top 10% customers by revenue',
    segment_type: :rfm,
    criteria: {
      recency_days: 90,
      min_frequency: 5,
      min_monetary: 50000
    },
    auto_update: true
  },
  {
    name: 'At Risk Customers',
    description: 'Previously active customers who haven\'t purchased recently',
    segment_type: :rfm,
    criteria: {
      recency_days: 180,
      min_frequency: 2,
      min_monetary: 10000
    },
    auto_update: true
  },
  {
    name: 'New Customers',
    description: 'Customers who joined in the last 30 days',
    segment_type: :behavioral,
    criteria: { days_since_signup: 30 },
    auto_update: true
  },
  {
    name: 'Engaged Users',
    description: 'Users with high engagement (frequent logins)',
    segment_type: :engagement,
    criteria: {
      min_logins: 10,
      active_days: 30
    },
    auto_update: true
  },
  {
    name: 'Repeat Buyers',
    description: 'Customers with 3+ orders',
    segment_type: :rfm,
    criteria: {
      recency_days: 365,
      min_frequency: 3,
      min_monetary: 5000
    },
    auto_update: true
  }
]

segments.each do |segment_data|
  CustomerSegment.find_or_create_by!(name: segment_data[:name]) do |segment|
    segment.description = segment_data[:description]
    segment.segment_type = segment_data[:segment_type]
    segment.criteria = segment_data[:criteria]
    segment.auto_update = segment_data[:auto_update]
    segment.active = true
  end
end

puts "✅ Created #{CustomerSegment.count} customer segments"

# Record sample analytics metrics for the past 30 days
puts "Recording sample analytics metrics..."

(30.days.ago.to_date..Date.current).each do |date|
  # Revenue metrics
  daily_revenue = rand(1000..5000)
  AnalyticsMetric.find_or_create_by!(
    metric_name: 'daily_revenue',
    metric_type: :revenue,
    date: date
  ) do |metric|
    metric.value = daily_revenue
  end
  
  # Order metrics
  daily_orders = rand(20..100)
  AnalyticsMetric.find_or_create_by!(
    metric_name: 'daily_orders',
    metric_type: :orders,
    date: date
  ) do |metric|
    metric.value = daily_orders
  end
  
  # Customer metrics
  new_customers = rand(5..20)
  AnalyticsMetric.find_or_create_by!(
    metric_name: 'new_customers',
    metric_type: :customers,
    date: date
  ) do |metric|
    metric.value = new_customers
  end
  
  # Conversion metrics
  conversion_rate = rand(2.0..5.0).round(2)
  AnalyticsMetric.find_or_create_by!(
    metric_name: 'conversion_rate',
    metric_type: :conversion,
    date: date
  ) do |metric|
    metric.value = conversion_rate
  end
end

puts "✅ Recorded metrics for 30 days"

# Create sample predictive models
puts "Creating predictive models..."

models = [
  {
    model_name: 'Customer LTV Predictor',
    model_type: 'ltv_prediction',
    description: 'Predicts customer lifetime value based on historical behavior',
    accuracy: 78.5,
    trained_at: 7.days.ago
  },
  {
    model_name: 'Churn Predictor',
    model_type: 'churn_prediction',
    description: 'Predicts probability of customer churn',
    accuracy: 82.3,
    trained_at: 5.days.ago
  },
  {
    model_name: 'Demand Forecaster',
    model_type: 'demand_forecast',
    description: 'Forecasts product demand for inventory planning',
    accuracy: 75.8,
    trained_at: 3.days.ago
  },
  {
    model_name: 'Revenue Forecaster',
    model_type: 'revenue_forecast',
    description: 'Forecasts future revenue based on trends',
    accuracy: 80.2,
    trained_at: 1.day.ago
  }
]

models.each do |model_data|
  PredictiveModel.find_or_create_by!(
    model_name: model_data[:model_name]
  ) do |model|
    model.model_type = model_data[:model_type]
    model.description = model_data[:description]
    model.accuracy = model_data[:accuracy]
    model.trained_at = model_data[:trained_at]
    model.active = true
    model.configuration = {
      algorithm: 'linear_regression',
      features: ['historical_data', 'trends', 'seasonality']
    }
  end
end

puts "✅ Created #{PredictiveModel.count} predictive models"

puts "🎉 Business Intelligence System seeded successfully!"
puts ""
puts "Summary:"
puts "  - #{AnalyticsReport.count} analytics reports"
puts "  - #{CustomerSegment.count} customer segments"
puts "  - #{AnalyticsMetric.count} analytics metrics"
puts "  - #{PredictiveModel.count} predictive models"
puts ""
puts "Next steps:"
puts "  1. Update customer segments: CustomerSegmentUpdateJob.perform_now"
puts "  2. Execute reports: AnalyticsReport.first.execute"
puts "  3. View metrics: AnalyticsMetric.trend('daily_revenue', 30)"

