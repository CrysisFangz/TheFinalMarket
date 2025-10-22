# 🚀 AdminUserShowQuery: CQRS Query Object for User Show
# Optimized for O(1) Caching and Comprehensive Data Aggregation
class AdminUserShowQuery
  def self.call(user_id:)
    new(user_id).execute
  end

  def initialize(user_id)
    @user_id = user_id
  end

  def execute
    user = Rails.cache.fetch("admin_user_#{@user_id}", expires_in: 60.seconds) do
      User.includes(
        :orders, :reviews, :disputes, :behavioral_profiles,
        :risk_assessments, :compliance_records
      ).find(@user_id)
    end

    # Aggregate Services Data
    profile = AdminUserProfileService.new(user).generate_comprehensive_profile
    intelligence = BehavioralIntelligenceService.new(user).analyze_behavior_patterns
    risk = RiskAssessmentService.new(user).generate_detailed_assessment
    compliance = ComplianceMonitoringService.new(user).monitor_all_compliance
    financial = FinancialImpactService.new(user).calculate_user_impact
    social = SocialNetworkService.new(user).analyze_connections
    reputation = ReputationAnalysisService.new(user).analyze_reputation_trends
    timeline = ActivityTimelineService.new(user).generate_timeline_with_insights
    predictive = PredictiveModelingService.new(user).generate_behavior_predictions

    { user: user, profile: profile, intelligence: intelligence, risk: risk, compliance: compliance, financial: financial, social: social, reputation: reputation, timeline: timeline, predictive: predictive }
  end
end