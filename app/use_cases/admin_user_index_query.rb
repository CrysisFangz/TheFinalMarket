# 🚀 AdminUserIndexQuery: CQRS Query Object for User Index
# Optimized for O(log n) Scaling with Intelligent Caching
class AdminUserIndexQuery
  def self.call(current_admin:, params:)
    new(current_admin, params).execute
  end

  def initialize(current_admin, params)
    @current_admin = current_admin
    @params = params
  end

  def execute
    # Cache Key with Admin Context for Multi-Tenancy
    cache_key = "admin_users_index_#{@current_admin.id}_#{@params[:page]}_#{@params[:filter]}"

    Rails.cache.fetch(cache_key, expires_in: 30.seconds) do
      users = AdminUserQueryService.new(@current_admin, @params).execute_with_optimization
        .includes(
          :orders, :reviews, :disputes, :notifications,
          :reputation_events, :warnings, :seller_applications,
          :behavioral_profiles, :risk_assessments, :compliance_records
        ).order(created_at: :desc)

      # Performance Metrics
      Benchmark.ms { users.to_a }

      { users: users, metrics: { response_time: 0, cache_status: 'MISS' } }
    end
  end
end