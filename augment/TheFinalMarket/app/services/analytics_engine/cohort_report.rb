module AnalyticsEngine
  class CohortReport < BaseReport
    def generate_data
      {
        cohort_table: generate_cohort_table,
        retention_rates: calculate_retention_rates,
        cohort_revenue: calculate_cohort_revenue
      }
    end
    
    def generate_summary
      {
        total_cohorts: cohort_data.keys.count,
        average_retention_rate: format_percentage(average_retention_rate),
        best_cohort: best_performing_cohort,
        worst_cohort: worst_performing_cohort
      }
    end
    
    def generate_visualizations
      [
        {
          type: 'heatmap',
          title: 'Cohort Retention Heatmap',
          data: generate_cohort_table
        },
        {
          type: 'line_chart',
          title: 'Cohort Retention Curves',
          data: retention_curves_data
        }
      ]
    end
    
    private
    
    def cohort_period
      params[:cohort_period] || 'month'
    end
    
    def cohort_data
      @cohort_data ||= begin
        users = User.where('created_at >= ?', 12.months.ago)
        
        users.group_by { |u| u.created_at.beginning_of_month }.transform_values do |cohort_users|
          cohort_users.map(&:id)
        end
      end
    end
    
    def generate_cohort_table
      table = {}
      
      cohort_data.each do |cohort_date, user_ids|
        table[cohort_date.strftime('%Y-%m')] = {}
        
        (0..11).each do |month_offset|
          period_start = cohort_date + month_offset.months
          period_end = period_start.end_of_month
          
          active_users = Order.where(user_id: user_ids)
                              .where(created_at: period_start..period_end)
                              .distinct
                              .count(:user_id)
          
          retention_rate = (active_users.to_f / user_ids.count * 100).round(2)
          table[cohort_date.strftime('%Y-%m')]["Month #{month_offset}"] = retention_rate
        end
      end
      
      table
    end
    
    def calculate_retention_rates
      rates = {}
      
      (0..11).each do |month_offset|
        total_retention = 0
        cohort_count = 0
        
        cohort_data.each do |cohort_date, user_ids|
          next if cohort_date + month_offset.months > Time.current
          
          period_start = cohort_date + month_offset.months
          period_end = period_start.end_of_month
          
          active_users = Order.where(user_id: user_ids)
                              .where(created_at: period_start..period_end)
                              .distinct
                              .count(:user_id)
          
          retention_rate = active_users.to_f / user_ids.count * 100
          total_retention += retention_rate
          cohort_count += 1
        end
        
        rates["Month #{month_offset}"] = cohort_count > 0 ? (total_retention / cohort_count).round(2) : 0
      end
      
      rates
    end
    
    def calculate_cohort_revenue
      revenue = {}
      
      cohort_data.each do |cohort_date, user_ids|
        cohort_revenue = Order.where(user_id: user_ids, status: 'completed')
                              .sum(:total_cents)
        
        revenue[cohort_date.strftime('%Y-%m')] = (cohort_revenue / 100.0).round(2)
      end
      
      revenue
    end
    
    def average_retention_rate
      rates = calculate_retention_rates
      return 0 if rates.empty?
      
      rates.values.sum / rates.values.count.to_f
    end
    
    def best_performing_cohort
      revenue = calculate_cohort_revenue
      return nil if revenue.empty?
      
      revenue.max_by { |_, v| v }&.first
    end
    
    def worst_performing_cohort
      revenue = calculate_cohort_revenue
      return nil if revenue.empty?
      
      revenue.min_by { |_, v| v }&.first
    end
    
    def retention_curves_data
      curves = {}
      
      cohort_data.first(5).each do |cohort_date, user_ids|
        curve_data = {}
        
        (0..11).each do |month_offset|
          period_start = cohort_date + month_offset.months
          period_end = period_start.end_of_month
          
          active_users = Order.where(user_id: user_ids)
                              .where(created_at: period_start..period_end)
                              .distinct
                              .count(:user_id)
          
          retention_rate = (active_users.to_f / user_ids.count * 100).round(2)
          curve_data["Month #{month_offset}"] = retention_rate
        end
        
        curves[cohort_date.strftime('%Y-%m')] = curve_data
      end
      
      curves
    end
  end
end

