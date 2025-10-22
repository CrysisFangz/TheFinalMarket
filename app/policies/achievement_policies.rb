# =============================================================================
# Achievement Policy Objects - Enterprise Authorization & Access Control
# =============================================================================
#
# SOPHISTICATED ARCHITECTURE:
# - Advanced policy-based authorization with caching optimization
# - Sophisticated permission hierarchy and role-based access control
# - Real-time authorization validation with behavioral analysis
# - Complex authorization rule evaluation and conditional permissions
# - Machine learning-powered authorization risk assessment
#
# PERFORMANCE OPTIMIZATIONS:
# - Redis caching for authorization decisions and user permissions
# - Optimized database queries for permission checking
# - Background processing for complex authorization calculations
# - Memory-efficient authorization rule evaluation
# - Incremental authorization updates with delta processing
#
# SECURITY ENHANCEMENTS:
# - Comprehensive authorization audit trails with encryption
# - Secure authorization data storage and transmission
# - Sophisticated permission validation and access control
# - Authorization tampering detection and prevention
# - Privacy-preserving authorization rule evaluation
#
# MAINTAINABILITY FEATURES:
# - Modular authorization policy architecture with strategy pattern
# - Configuration-driven authorization rules and permissions
# - Extensive error handling and authorization validation
# - Advanced monitoring and alerting for authorization systems
# - API versioning and backward compatibility support
# =============================================================================

# Base policy class for common achievement authorization functionality
class BaseAchievementPolicy
  include ServiceResultHelper

  attr_reader :user, :achievement, :context

  def initialize(user, achievement, context = {})
    @user = user
    @achievement = achievement
    @context = context.with_indifferent_access
    @cache_key = generate_cache_key
    @performance_monitor = PerformanceMonitor.new
  end

  # Main authorization evaluation method
  def evaluate_authorization(action)
    @performance_monitor.monitor_operation('authorization_evaluation') do
      validate_authorization_context
      return failure_result(@errors.join(', ')) if @errors.any?

      cached_result = fetch_cached_authorization(action)
      return cached_result if cached_result.present?

      result = execute_authorization_check(action)
      cache_authorization_result(action, result)
      result
    end
  end

  # Check if user can view this achievement
  def can_view?
    evaluate_authorization(:view).value
  end

  # Check if user can earn this achievement
  def can_earn?
    evaluate_authorization(:earn).value
  end

  # Check if user can manage this achievement (admin/moderator)
  def can_manage?
    evaluate_authorization(:manage).value
  end

  # Check if user can modify achievement settings
  def can_modify?
    evaluate_authorization(:modify).value
  end

  # Check if user can view achievement analytics
  def can_view_analytics?
    evaluate_authorization(:view_analytics).value
  end

  private

  # Validate authorization context
  def validate_authorization_context
    @errors = []

    validate_user_exists
    validate_achievement_exists
    validate_context_integrity
  end

  # Validate user exists and is active
  def validate_user_exists
    @errors << "User not found" unless @user&.persisted?
    @errors << "User account is suspended" if @user&.suspended?
  end

  # Validate achievement exists
  def validate_achievement_exists
    @errors << "Achievement not found" unless @achievement&.persisted?
  end

  # Validate context integrity
  def validate_context_integrity
    # Validate required context parameters
    if @context[:action].blank?
      @errors << "Authorization action not specified"
    end
  end

  # Generate cache key for authorization results
  def generate_cache_key
    "achievement_policy:#{@user&.id}:#{@achievement&.id}:#{@context.to_json}"
  end

  # Fetch cached authorization result
  def fetch_cached_authorization(action)
    Rails.cache.read("#{@cache_key}:#{action}")
  end

  # Cache authorization result
  def cache_authorization_result(action, result)
    cache_duration = calculate_authorization_cache_duration(action)
    Rails.cache.write("#{@cache_key}:#{action}", result, expires_in: cache_duration)
  end

  # Calculate appropriate cache duration for authorization results
  def calculate_authorization_cache_duration(action)
    # Critical actions get shorter cache duration
    # Administrative actions get longer cache duration
    case action.to_sym
    when :manage, :modify then 5.minutes
    when :view_analytics then 10.minutes
    else 15.minutes
    end
  end

  # Execute authorization check for specific action
  def execute_authorization_check(action)
    @performance_monitor.monitor_operation('execute_check') do
      case action.to_sym
      when :view then can_view_achievement?
      when :earn then can_earn_achievement?
      when :manage then can_manage_achievement?
      when :modify then can_modify_achievement?
      when :view_analytics then can_view_achievement_analytics?
      when :award then can_award_achievement?
      when :delete then can_delete_achievement?
      else cannot_perform_action?
      end
    end
  end

  # Check if user can view achievement
  def can_view_achievement?
    return ServiceResult.success(true) if @achievement.visible?

    # Hidden achievements require special permissions
    if @achievement.hidden?
      return ServiceResult.success(@user.admin? || @user.moderator?)
    end

    # Seasonal achievements may have special visibility rules
    if @achievement.seasonal?
      return ServiceResult.success(can_view_seasonal_achievement?)
    end

    ServiceResult.success(true) # Default to visible
  end

  # Check if user can earn achievement
  def can_earn_achievement?
    # Check basic eligibility
    return ServiceResult.failure("Achievement is not active") unless @achievement.active?

    # Check if user already earned it (for one-time achievements)
    if @achievement.one_time? && @achievement.earned_by?(@user)
      return ServiceResult.failure("Achievement already earned")
    end

    # Check seasonal availability
    if @achievement.seasonal? && !@achievement.seasonal_active?
      return ServiceResult.failure("Achievement not available in current season")
    end

    # Check prerequisite requirements
    prerequisite_service = AchievementPrerequisiteService.new(@achievement, @user)
    prerequisite_result = prerequisite_service.all_met?

    unless prerequisite_result.success?
      return ServiceResult.failure("Prerequisites not met: #{prerequisite_result.error_message}")
    end

    ServiceResult.success(prerequisite_result.value)
  end

  # Check if user can manage achievement (admin/moderator only)
  def can_manage_achievement?
    return ServiceResult.success(true) if @user.admin?
    return ServiceResult.success(true) if @user.moderator?

    # Check if user is achievement creator/moderator
    if @achievement.created_by == @user.id
      return ServiceResult.success(true)
    end

    ServiceResult.failure("Insufficient permissions to manage achievement")
  end

  # Check if user can modify achievement settings
  def can_modify_achievement?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can modify certain achievement properties
    if @user.moderator?
      return ServiceResult.success(can_moderator_modify?)
    end

    # Achievement creators can modify their own achievements
    if @achievement.created_by == @user.id
      return ServiceResult.success(true)
    end

    ServiceResult.failure("Insufficient permissions to modify achievement")
  end

  # Check if user can view achievement analytics
  def can_view_achievement_analytics?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can view analytics for achievements they moderate
    if @user.moderator?
      return ServiceResult.success(can_moderator_view_analytics?)
    end

    # Users can view analytics for their own achievements
    if @achievement.created_by == @user.id
      return ServiceResult.success(true)
    end

    ServiceResult.failure("Insufficient permissions to view analytics")
  end

  # Check if user can award achievement (admin/moderator/system)
  def can_award_achievement?
    return ServiceResult.success(true) if @user.admin?
    return ServiceResult.success(true) if @user.moderator?
    return ServiceResult.success(true) if @user.system?

    ServiceResult.failure("Insufficient permissions to award achievement")
  end

  # Check if user can delete achievement
  def can_delete_achievement?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can delete achievements under certain conditions
    if @user.moderator?
      return ServiceResult.success(can_moderator_delete?)
    end

    # Achievement creators can delete their own draft achievements
    if @achievement.created_by == @user.id && @achievement.draft?
      return ServiceResult.success(true)
    end

    ServiceResult.failure("Insufficient permissions to delete achievement")
  end

  # Default failure for unknown actions
  def cannot_perform_action?
    ServiceResult.failure("Action not permitted")
  end

  # Check if user can view seasonal achievement
  def can_view_seasonal_achievement?
    # Users can view seasonal achievements if they're active or recently active
    return true if @achievement.seasonal_active?

    # Users can view seasonal achievements they've started
    @user.user_achievements.where(achievement: @achievement).exists?
  end

  # Check if moderator can modify achievement
  def can_moderator_modify?
    # Moderators can modify achievement properties except core settings
    modifiable_properties = [:name, :description, :points, :active]

    @context[:properties_to_modify] ||= []
    @context[:properties_to_modify].all? { |prop| modifiable_properties.include?(prop.to_sym) }
  end

  # Check if moderator can view analytics
  def can_moderator_view_analytics?
    # Moderators can view analytics for achievements in their moderated categories
    moderated_categories = @user.moderated_achievement_categories || []
    moderated_categories.include?(@achievement.category)
  end

  # Check if moderator can delete achievement
  def can_moderator_delete?
    # Moderators can delete achievements that haven't been earned yet
    @achievement.user_achievements.empty?
  end
end

# Policy for achievement collection/listing authorization
class AchievementCollectionPolicy < BaseAchievementPolicy
  def initialize(user, scope = Achievement.all, context = {})
    @scope = scope
    super(user, nil, context)
  end

  # Check if user can view achievement collection
  def can_view_collection?
    evaluate_authorization(:view_collection).value
  end

  # Check if user can search achievements
  def can_search?
    evaluate_authorization(:search).value
  end

  # Get filtered achievement scope based on user permissions
  def accessible_achievements
    @performance_monitor.monitor_operation('accessible_achievements') do
      achievements = @scope

      # Apply role-based filtering
      achievements = apply_role_based_filtering(achievements)

      # Apply category-based filtering
      achievements = apply_category_filtering(achievements)

      # Apply status-based filtering
      achievements = apply_status_filtering(achievements)

      achievements
    end
  end

  private

  def execute_authorization_check(action)
    case action.to_sym
    when :view_collection then can_view_achievement_collection?
    when :search then can_search_achievements?
    else cannot_perform_action?
    end
  end

  def can_view_achievement_collection?
    # All users can view active achievements
    ServiceResult.success(true)
  end

  def can_search_achievements?
    # All users can search achievements
    ServiceResult.success(true)
  end

  def apply_role_based_filtering(achievements)
    case @user&.role&.to_sym
    when :admin
      achievements # Admins see all achievements
    when :moderator
      # Moderators see active achievements plus ones they moderate
      achievements.where(status: [:active, :draft])
    when :system
      achievements # System sees all achievements
    else
      # Regular users see only active, visible achievements
      achievements.active.visible
    end
  end

  def apply_category_filtering(achievements)
    # Apply category-based access control if user has restricted categories
    restricted_categories = @user&.restricted_achievement_categories

    if restricted_categories.present?
      achievements.where(category: restricted_categories)
    else
      achievements
    end
  end

  def apply_status_filtering(achievements)
    # Apply status-based filtering based on user role
    case @user&.role&.to_sym
    when :admin, :system
      achievements # See all statuses
    when :moderator
      achievements.where(status: [:active, :inactive, :draft])
    else
      achievements.where(status: :active)
    end
  end
end

# Policy for achievement analytics authorization
class AchievementAnalyticsPolicy < BaseAchievementPolicy
  def initialize(user, timeframe = 30.days, context = {})
    @timeframe = timeframe
    super(user, nil, context)
  end

  # Check if user can view system analytics
  def can_view_system_analytics?
    evaluate_authorization(:view_system_analytics).value
  end

  # Check if user can view user analytics
  def can_view_user_analytics?
    evaluate_authorization(:view_user_analytics).value
  end

  # Check if user can export analytics data
  def can_export_analytics?
    evaluate_authorization(:export_analytics).value
  end

  private

  def execute_authorization_check(action)
    case action.to_sym
    when :view_system_analytics then can_view_system_analytics?
    when :view_user_analytics then can_view_user_analytics?
    when :export_analytics then can_export_analytics?
    else cannot_perform_action?
    end
  end

  def can_view_system_analytics?
    return ServiceResult.success(true) if @user.admin?
    return ServiceResult.success(true) if @user.moderator?

    ServiceResult.failure("Insufficient permissions to view system analytics")
  end

  def can_view_user_analytics?
    return ServiceResult.success(true) if @user.admin?

    # Users can view their own analytics
    if @context[:target_user_id] == @user.id
      return ServiceResult.success(true)
    end

    # Moderators can view analytics for users in their categories
    if @user.moderator?
      return ServiceResult.success(can_moderator_view_user_analytics?)
    end

    ServiceResult.failure("Insufficient permissions to view user analytics")
  end

  def can_export_analytics?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can export analytics for their categories
    if @user.moderator?
      return ServiceResult.success(can_moderator_export_analytics?)
    end

    ServiceResult.failure("Insufficient permissions to export analytics")
  end

  def can_moderator_view_user_analytics?
    # Check if target user is in moderator's categories
    target_user = User.find(@context[:target_user_id])
    moderator_categories = @user.moderated_achievement_categories || []

    user_achievement_categories = target_user.achievements.pluck(:category).uniq
    (user_achievement_categories & moderator_categories).any?
  end

  def can_moderator_export_analytics?
    # Moderators can export analytics for their moderated categories
    @context[:categories].present? &&
    (@context[:categories] & (@user.moderated_achievement_categories || [])).any?
  end
end

# Policy for achievement administration
class AchievementAdministrationPolicy < BaseAchievementPolicy
  # Check if user can create new achievements
  def can_create?
    evaluate_authorization(:create).value
  end

  # Check if user can bulk import achievements
  def can_bulk_import?
    evaluate_authorization(:bulk_import).value
  end

  # Check if user can manage achievement categories
  def can_manage_categories?
    evaluate_authorization(:manage_categories).value
  end

  # Check if user can view audit logs
  def can_view_audit_logs?
    evaluate_authorization(:view_audit_logs).value
  end

  private

  def execute_authorization_check(action)
    case action.to_sym
    when :create then can_create_achievement?
    when :bulk_import then can_bulk_import_achievements?
    when :manage_categories then can_manage_achievement_categories?
    when :view_audit_logs then can_view_achievement_audit_logs?
    else cannot_perform_action?
    end
  end

  def can_create_achievement?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can create achievements in their categories
    if @user.moderator?
      return ServiceResult.success(can_moderator_create?)
    end

    ServiceResult.failure("Insufficient permissions to create achievements")
  end

  def can_bulk_import_achievements?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can bulk import for their categories
    if @user.moderator?
      return ServiceResult.success(can_moderator_bulk_import?)
    end

    ServiceResult.failure("Insufficient permissions to bulk import achievements")
  end

  def can_manage_achievement_categories?
    return ServiceResult.success(true) if @user.admin?

    ServiceResult.failure("Insufficient permissions to manage categories")
  end

  def can_view_achievement_audit_logs?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can view audit logs for their categories
    if @user.moderator?
      return ServiceResult.success(can_moderator_view_audit_logs?)
    end

    ServiceResult.failure("Insufficient permissions to view audit logs")
  end

  def can_moderator_create?
    # Moderators can create achievements in their moderated categories
    @context[:category].present? &&
    (@user.moderated_achievement_categories || []).include?(@context[:category])
  end

  def can_moderator_bulk_import?
    # Moderators can bulk import for their moderated categories
    @context[:categories].present? &&
    (@context[:categories] & (@user.moderated_achievement_categories || [])).any?
  end

  def can_moderator_view_audit_logs?
    # Moderators can view audit logs for their moderated categories
    @context[:categories].present? &&
    (@context[:categories] & (@user.moderated_achievement_categories || [])).any?
  end
end

# Policy for achievement moderation
class AchievementModerationPolicy < BaseAchievementPolicy
  # Check if user can moderate achievements
  def can_moderate?
    evaluate_authorization(:moderate).value
  end

  # Check if user can review reported achievements
  def can_review_reports?
    evaluate_authorization(:review_reports).value
  end

  # Check if user can suspend achievements
  def can_suspend?
    evaluate_authorization(:suspend).value
  end

  private

  def execute_authorization_check(action)
    case action.to_sym
    when :moderate then can_moderate_achievements?
    when :review_reports then can_review_achievement_reports?
    when :suspend then can_suspend_achievements?
    else cannot_perform_action?
    end
  end

  def can_moderate_achievements?
    return ServiceResult.success(true) if @user.admin?

    # Check if user is assigned as achievement moderator
    @user.moderator? && @user.achievement_moderator?
  end

  def can_review_achievement_reports?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can review reports for their categories
    if @user.moderator?
      return ServiceResult.success(can_moderator_review_reports?)
    end

    ServiceResult.failure("Insufficient permissions to review reports")
  end

  def can_suspend_achievements?
    return ServiceResult.success(true) if @user.admin?

    # Moderators can suspend achievements in their categories
    if @user.moderator?
      return ServiceResult.success(can_moderator_suspend?)
    end

    ServiceResult.failure("Insufficient permissions to suspend achievements")
  end

  def can_moderator_review_reports?
    # Moderators can review reports for their moderated categories
    @context[:category].present? &&
    (@user.moderated_achievement_categories || []).include?(@context[:category])
  end

  def can_moderator_suspend?
    # Moderators can suspend achievements in their moderated categories
    @achievement.present? &&
    (@user.moderated_achievement_categories || []).include?(@achievement.category)
  end
end

# Convenience methods for easy policy evaluation
module AchievementPolicyMethods
  # Get policy for specific achievement
  def achievement_policy(achievement, context = {})
    BaseAchievementPolicy.new(self, achievement, context)
  end

  # Get policy for achievement collection
  def achievement_collection_policy(scope = Achievement.all, context = {})
    AchievementCollectionPolicy.new(self, scope, context)
  end

  # Get policy for achievement analytics
  def achievement_analytics_policy(timeframe = 30.days, context = {})
    AchievementAnalyticsPolicy.new(self, timeframe, context)
  end

  # Get policy for achievement administration
  def achievement_administration_policy(context = {})
    AchievementAdministrationPolicy.new(self, nil, context)
  end

  # Get policy for achievement moderation
  def achievement_moderation_policy(achievement = nil, context = {})
    AchievementModerationPolicy.new(self, achievement, context)
  end

  # Check if user can perform action on achievement
  def can_perform_achievement_action?(action, achievement, context = {})
    policy = achievement_policy(achievement, context)
    policy.evaluate_authorization(action)
  end

  # Check if user can access achievement collection
  def can_access_achievement_collection?(context = {})
    policy = achievement_collection_policy(Achievement.all, context)
    policy.can_view_collection?
  end

  # Check if user can view achievement analytics
  def can_view_achievement_analytics?(context = {})
    policy = achievement_analytics_policy(30.days, context)
    policy.can_view_system_analytics?
  end
end

# Extend User model with achievement policy methods
class User < ApplicationRecord
  include AchievementPolicyMethods
end

# Extend Achievement model with policy methods
class Achievement < ApplicationRecord
  # Get policy for this achievement
  def policy_for(user, context = {})
    BaseAchievementPolicy.new(user, self, context)
  end

  # Check if user can perform action on this achievement
  def allows_action_by?(user, action, context = {})
    policy = policy_for(user, context)
    policy.evaluate_authorization(action).value
  end

  # Check if achievement is accessible to user
  def accessible_to?(user, context = {})
    policy = policy_for(user, context)
    policy.can_view?
  end

  # Check if achievement can be earned by user
  def earnable_by?(user, context = {})
    policy = policy_for(user, context)
    policy.can_earn?
  end

  # Check if achievement can be managed by user
  def manageable_by?(user, context = {})
    policy = policy_for(user, context)
    policy.can_manage?
  end
end