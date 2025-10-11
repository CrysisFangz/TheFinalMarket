module AnalyticsEngine
  class CustomerReport < BaseReport
    def generate_data
      {
        customer_acquisition: customer_acquisition_data,
        customer_segments: customer_segmentation_data,
        top_customers: top_customers_by_value,
        customer_lifetime_value: ltv_distribution,
        churn_analysis: churn_analysis_data
      }
    end
    
    def generate_summary
      {
        total_customers: total_customers,
        new_customers: new_customers_count,
        active_customers: active_customers_count,
        churned_customers: churned_customers_count,
        avg_customer_value: format_currency(average_customer_value),
        customer_retention_rate: format_percentage(retention_rate)
      }
    end
    
    def generate_visualizations
      [
        {
          type: 'line_chart',
          title: 'Customer Acquisition',
          data: customer_acquisition_data
        },
        {
          type: 'pie_chart',
          title: 'Customer Segments',
          data: customer_segmentation_data
        },
        {
          type: 'bar_chart',
          title: 'Top Customers by Value',
          data: top_customers_by_value.first(10)
        }
      ]
    end
    
    private
    
    def total_customers
      User.count
    end
    
    def new_customers_count
      User.where(created_at: date_range).count
    end
    
    def active_customers_count
      User.joins(:orders)
          .where(orders: { created_at: date_range, status: 'completed' })
          .distinct
          .count
    end
    
    def churned_customers_count
      # Customers who haven't ordered in 90+ days
      User.joins(:orders)
          .where(orders: { status: 'completed' })
          .group('users.id')
          .having('MAX(orders.created_at) < ?', 90.days.ago)
          .count
          .count
    end
    
    def average_customer_value
      Order.where(status: 'completed')
           .group(:user_id)
           .sum(:total_cents)
           .values
           .sum / [total_customers, 1].max.to_f
    end
    
    def retention_rate
      beginning_customers = User.where('created_at < ?', date_range.begin).count
      return 0 if beginning_customers.zero?
      
      retained = User.where('created_at < ?', date_range.begin)
                    .joins(:orders)
                    .where(orders: { created_at: date_range, status: 'completed' })
                    .distinct
                    .count
      
      (retained.to_f / beginning_customers * 100).round(2)
    end
    
    def customer_acquisition_data
      User.where(created_at: date_range)
          .group_by_day(:created_at)
          .count
    end
    
    def customer_segmentation_data
      segments = {
        'New' => User.where('created_at > ?', 30.days.ago).count,
        'Active' => active_customers_count,
        'At Risk' => at_risk_customers_count,
        'Churned' => churned_customers_count
      }
      
      segments
    end
    
    def at_risk_customers_count
      # Customers who haven't ordered in 30-90 days
      User.joins(:orders)
          .where(orders: { status: 'completed' })
          .group('users.id')
          .having('MAX(orders.created_at) BETWEEN ? AND ?', 90.days.ago, 30.days.ago)
          .count
          .count
    end
    
    def top_customers_by_value
      User.joins(:orders)
          .where(orders: { status: 'completed' })
          .group('users.id', 'users.name')
          .select('users.name, SUM(orders.total_cents) as total_value')
          .order('total_value DESC')
          .limit(20)
          .map { |u| [u.name, (u.total_value / 100.0).round(2)] }
          .to_h
    end
    
    def ltv_distribution
      customer_values = User.joins(:orders)
                           .where(orders: { status: 'completed' })
                           .group('users.id')
                           .sum('orders.total_cents')
                           .values
                           .map { |v| v / 100.0 }
      
      {
        '0-100' => customer_values.count { |v| v < 100 },
        '100-500' => customer_values.count { |v| v >= 100 && v < 500 },
        '500-1000' => customer_values.count { |v| v >= 500 && v < 1000 },
        '1000-5000' => customer_values.count { |v| v >= 1000 && v < 5000 },
        '5000+' => customer_values.count { |v| v >= 5000 }
      }
    end
    
    def churn_analysis_data
      {
        churn_rate: format_percentage(calculate_churn_rate),
        avg_customer_lifespan: calculate_avg_lifespan,
        churn_reasons: analyze_churn_reasons
      }
    end
    
    def calculate_churn_rate
      total = User.where('created_at < ?', 90.days.ago).count
      return 0 if total.zero?
      
      churned = churned_customers_count
      (churned.to_f / total * 100).round(2)
    end
    
    def calculate_avg_lifespan
      # Average time from first to last order
      lifespans = User.joins(:orders)
                     .where(orders: { status: 'completed' })
                     .group('users.id')
                     .select('users.id, MAX(orders.created_at) - MIN(orders.created_at) as lifespan')
                     .map(&:lifespan)
                     .compact
      
      return 0 if lifespans.empty?
      
      avg_seconds = lifespans.sum / lifespans.count.to_f
      (avg_seconds / 1.day).round(1)
    end
    
    def analyze_churn_reasons
      # This would integrate with customer feedback/surveys
      # For now, return placeholder data
      {
        'Price' => 25,
        'Product Quality' => 20,
        'Customer Service' => 15,
        'Competition' => 30,
        'Other' => 10
      }
    end
  end
end

