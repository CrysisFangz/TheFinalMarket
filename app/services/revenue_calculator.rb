# app/services/revenue_calculator.rb
class RevenueCalculator
  include Singleton

  def monthly_revenue
    Rails.cache.fetch('monthly_revenue', expires_in: 1.hour) do
      StoreOrder.where('created_at >= ?', 1.month.ago).sum(:total_amount)
    end
  end

  def invalidate_cache
    Rails.cache.delete('monthly_revenue')
  end
end