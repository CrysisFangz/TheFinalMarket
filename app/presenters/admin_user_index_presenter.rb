# 🚀 AdminUserIndexPresenter: Hexagonal Architecture Presenter for User Index Data
# Ensures Clean Separation of Data and Presentation Logic
class AdminUserIndexPresenter
  def initialize(result)
    @users = result[:users]
    @metrics = result[:metrics]
  end

  def users
    @users.map { |user| UserDecorator.new(user) }
  end

  def analytics
    # Aggregate analytics from services
    {
      segmentation: AiUserSegmentationService.new(@users).perform_intelligent_segmentation,
      patterns: BehavioralPatternService.new(@users).analyze_population_patterns,
      risk: RiskAssessmentService.new(@users).generate_risk_heatmap,
      compliance: ComplianceDashboardService.new(@users).generate_compliance_overview,
      geographic: GeographicAnalyticsService.new(@users).analyze_global_distribution
    }
  end

  def headers
    {
      'X-Admin-Users-Response-Time' => @metrics[:response_time].to_s + 'ms',
      'X-Cache-Status' => @metrics[:cache_status]
    }
  end

  private

  class UserDecorator
    def initialize(user)
      @user = user
    end

    def method_missing(method, *args)
      @user.public_send(method, *args)
    end
  end
end