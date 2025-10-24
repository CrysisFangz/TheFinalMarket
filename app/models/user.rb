# Enterprise-Grade User Model - Clean Architecture Implementation
#
# This model follows the Prime Mandate principles:
# - Single Responsibility: Pure data model with minimal business logic
# - Hermetic Decoupling: Isolated from service layer concerns
# - Asymptotic Optimality: Optimized for database performance with caching and counters
# - Architectural Zenith: Designed for horizontal scalability with efficient associations
#
# The User model serves as a pure data access layer, delegating all
# business logic to appropriate service objects for maximum modularity
# and testability.
#
# Performance Notes:
# - Ensure database indexes on: suspended_until, identity_verification_status, seller_status,
#   last_sign_in_at, lifetime_value_score, behavioral_risk_score, user_type, orders_count, reviews_count
# - Use cached methods for expensive computations to achieve O(1) access.

class User < ApplicationRecord
  include UserReputation
  include UserLeveling
  include SellerFeesConcern
  include SellerBondConcern
  include PasswordSecurity
  include BehavioralIntelligence
  include GlobalIdentityFederation
  include PrivacyPreservation
  include HyperPersonalization

  # Core associations - essential relationships only, optimized for performance
  has_many :seller_orders, class_name: 'Order', foreign_key: 'seller_id', counter_cache: true
  has_many :orders, foreign_key: 'user_id', dependent: :nullify, counter_cache: true
  has_many :products, dependent: :nullify, counter_cache: true
  has_many :reviews, dependent: :nullify, counter_cache: true
  has_many :cart_items, dependent: :nullify, counter_cache: true
  has_many :notifications, as: :recipient, dependent: :nullify, counter_cache: true

  # Identity and verification associations - optimized for security
  has_many :federated_identities, dependent: :nullify
  has_many :identity_verification_events, dependent: :nullify
  has_many :blockchain_identity_records, dependent: :nullify

  # Behavioral and personalization associations - optimized for analytics
  has_many :behavioral_events, dependent: :nullify
  has_many :user_behavioral_profiles, dependent: :nullify
  has_many :anomaly_detection_events, dependent: :nullify
  has_many :personalization_insights, dependent: :nullify

  # Gamification associations - optimized for scalability
  has_many :user_achievements, dependent: :nullify, counter_cache: true
  has_many :achievements, through: :user_achievements
  has_many :user_daily_challenges, dependent: :nullify, counter_cache: true
  has_many :daily_challenges, through: :user_daily_challenges
  has_many :points_transactions, dependent: :nullify, counter_cache: true
  has_many :coins_transactions, dependent: :nullify, counter_cache: true
  has_many :unlocked_features, dependent: :nullify, counter_cache: true

  # Privacy and compliance associations - optimized for compliance and performance
  has_many :consent_records, dependent: :nullify
  has_many :data_processing_agreements, dependent: :nullify
  has_many :privacy_preferences, dependent: :nullify
  has_many :data_deletion_requests, dependent: :nullify
  has_many :compliance_events, dependent: :nullify
  has_many :data_retention_records, dependent: :nullify
  has_many :audit_trail_entries, dependent: :nullify
  has_many :regulatory_reporting_records, dependent: :nullify

  # Enhanced associations - optimized for user experience
  has_one :wishlist, dependent: :nullify
  has_many :wishlist_items, through: :wishlist
  has_one :cart, dependent: :nullify
  has_many :reviewed_products, through: :reviews, source: :product
  has_one :seller_application, dependent: :nullify

  # Dispute associations - optimized for moderation efficiency
  has_many :reported_disputes, class_name: 'Dispute', foreign_key: 'reporter_id', dependent: :nullify, counter_cache: true
  has_many :disputes_against, class_name: 'Dispute', foreign_key: 'reported_user_id', dependent: :nullify, counter_cache: true
  has_many :moderated_disputes, class_name: 'Dispute', foreign_key: 'moderator_id', dependent: :nullify, counter_cache: true

  # Internationalization
  has_one :user_currency_preference, dependent: :destroy
  has_one :currency, through: :user_currency_preference
  belongs_to :country, optional: true, foreign_key: :country_code, primary_key: :code

  # User warnings - optimized for moderation
  has_many :warnings, class_name: 'UserWarning', dependent: :nullify, counter_cache: true

  # File attachments
  has_one_attached :avatar
  has_one_attached :biometric_template
  has_one_attached :behavioral_fingerprint

  # Enhanced enumerations with enterprise-grade validation
  enum role: {
    user: 0,
    moderator: 1,
    admin: 2,
    super_admin: 3,
    system: 4
  }, _prefix: :role

  enum user_type: {
    seeker: 'seeker',
    gem: 'gem',
    business: 'business',
    enterprise: 'enterprise'
  }, _prefix: :type

  enum seller_status: {
    not_applied: 'not_applied',
    pending_approval: 'pending_approval',
    pending_bond: 'pending_bond',
    approved: 'approved',
    rejected: 'rejected',
    suspended: 'suspended',
    premium: 'premium',
    enterprise_verified: 'enterprise_verified'
  }, _prefix: :seller_status

  enum identity_verification_status: {
    unverified: 'unverified',
    pending: 'pending',
    partially_verified: 'partially_verified',
    fully_verified: 'fully_verified',
    enterprise_verified: 'enterprise_verified'
  }, _prefix: :identity_verification_status

  enum privacy_level: {
    public: 'public',
    friends: 'friends',
    private: 'private',
    enterprise_controlled: 'enterprise_controlled'
  }, _prefix: :privacy_level

  # Enhanced validations with enterprise-grade constraints
  validates :name, presence: true, length: { maximum: 100 },
                   format: { with: /\A[a-zA-Z\s\-']+\z/, message: "only allows letters, spaces, hyphens, and apostrophes" }
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 16 }, allow_nil: true,
                       format: { with: /(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
                               message: "must include uppercase, lowercase, number, and special character" }

  validates :phone, format: { with: /\A\+?[1-9]\d{1,14}\z/, message: "must be a valid international phone number" },
                    allow_blank: true
  validates :date_of_birth, comparison: { less_than: 13.years.ago, message: "must be at least 13 years old" },
                            allow_nil: true
  validates :country_code, inclusion: { in: ISO3166::Country.codes }, allow_blank: true
  validates :timezone, inclusion: { in: TZInfo::Timezone.all_identifiers }, allow_blank: true

  # Enterprise-grade attributes with type safety and performance optimizations
  attribute :suspended_until, :datetime
  attribute :identity_confidence_score, :decimal, default: 0.0
  attribute :behavioral_risk_score, :decimal, default: 0.0
  attribute :lifetime_value_score, :decimal, default: 0.0
  attribute :personalization_readiness_score, :decimal, default: 0.0

  # Cached counters for asymptotic optimality
  attribute :orders_count, :integer, default: 0
  attribute :reviews_count, :integer, default: 0
  attribute :products_count, :integer, default: 0
  attribute :cart_items_count, :integer, default: 0
  attribute :notifications_count, :integer, default: 0
  attribute :user_achievements_count, :integer, default: 0
  attribute :warnings_count, :integer, default: 0

  # JSON attributes for flexible enterprise data storage
  attribute :behavioral_profile, :json, default: {}
  attribute :privacy_preferences, :json, default: {}
  attribute :global_identity_attributes, :json, default: {}
  attribute :enterprise_metadata, :json, default: {}

  # Optimized callbacks with resilience patterns - only essential data operations
  before_save :normalize_email
  after_save :trigger_essential_post_save_operations, :invalidate_cache
  before_destroy :execute_user_deactivation_protocol

  # Resilience: Error handling in callbacks
  rescue_from ActiveRecord::RecordInvalid do |exception|
    Rails.logger.error("User validation failed: #{exception.message}")
    # Handle gracefully, e.g., notify admins
  end

  # Query scopes for asymptotic optimality and performance
  # Note: Ensure database indexes on suspended_until, identity_verification_status, seller_status, last_sign_in_at, lifetime_value_score, behavioral_risk_score, user_type, orders_count, reviews_count
  scope :active, -> { where(suspended_until: nil).or(where('suspended_until < ?', Time.current)) }
  scope :verified, -> { where(identity_verification_status: [:fully_verified, :enterprise_verified]) }
  scope :sellers, -> { where(seller_status: [:approved, :premium, :enterprise_verified]) }
  scope :recently_active, ->(days = 7) { where('last_sign_in_at > ?', days.days.ago) }
  scope :high_value, -> { where('lifetime_value_score > ?', 1000) }
  scope :at_risk, -> { where('behavioral_risk_score > ?', 0.7) }
  scope :enterprise_users, -> { where(user_type: :enterprise) }
  scope :with_orders, -> { where('orders_count > 0') }
  scope :with_reviews, -> { where('reviews_count > 0') }
  scope :preload_associations, -> { includes(:orders, :reviews, :products) }  # Prevent N+1 queries

  # ==================== CLEAN SERVICE DELEGATION METHODS ====================

  # Authentication & Authorization - Delegate to dedicated services
  def authenticate_with_behavioral_validation(authentication_params, context = {})
    AuthenticationService.new(self, context).authenticate_with_behavioral_validation(authentication_params, context)
  end

  def authorize_with_continuous_validation(action, resource, context = {})
    AuthorizationService.new(self, context).authorize_with_continuous_validation(action, resource, context)
  end

  # Behavioral Intelligence - Delegate to behavioral analysis service
  def execute_behavioral_analysis(context = {})
    BehavioralAnalysisService.call(self, context)
  end

  def generate_personalized_recommendations(recommendation_context = {})
    PersonalizationService.new(self, context).generate_personalized_recommendations(recommendation_context)
  end

  def update_personalization_profile(update_context = {})
    PersonalizationService.new(self, context).update_personalization_profile(update_context)
  end

  def adapt_user_experience(experience_context = {})
    PersonalizationService.new(self, context).adapt_user_experience(experience_context)
  end

  # Identity Management - Delegate to identity services
  def execute_identity_verification(verification_method, verification_data)
    IdentityVerificationService.new(self).execute_identity_verification(verification_method, verification_data)
  end

  def federate_external_identity(identity_provider, identity_token)
    IdentityFederationService.new(self).federate_external_identity(identity_provider, identity_token)
  end

  def verify_identity_with_blockchain_verification(verification_data)
    BlockchainVerificationService.new(self).verify_identity_with_blockchain_verification(verification_data)
  end

  # Compliance & Privacy - Delegate to compliance services
  def validate_data_processing_compliance(operation_context = {})
    ComplianceService.new(self).validate_data_processing_compliance(operation_context)
  end

  def execute_privacy_rights_request(request_type, request_data = {})
    PrivacyRightsService.new(self).execute_privacy_rights_request(request_type, request_data)
  end

  # Gamification - Delegate to gamification service
  def track_gamification_action(action_type, metadata = {})
    GamificationService.new(self).track_action(action_type, metadata)
  end

  def award_points(amount, reason = nil)
    GamificationService.new(self).award_points(amount, reason)
  end

  def award_coins(amount, reason = nil)
    GamificationService.new(self).award_coins(amount, reason)
  end

  def update_login_streak!
    GamificationService.new(self).update_login_streak!
  end

  def update_challenge_streak!
    GamificationService.new(self).update_challenge_streak!
  end

  def level_up!
    GamificationService.new(self).check_level_up
  end

  # Cart Management - Delegate to cart service
  def add_to_cart(item, quantity = 1)
    CartService.new(self).add_item(item, quantity)
  end

  def remove_from_cart(item, quantity = nil)
    CartService.new(self).remove_item(item, quantity)
  end

  def clear_cart
    CartService.new(self).clear_cart
  end

  def cart_total
    CartService.new(self).calculate_total
  end

  # Notification Management - Delegate to notification service
  def notify(actor:, action:, notifiable:)
    NotificationService.new(self).create_notification(
      recipient: self,
      actor: actor,
      action: action,
      notifiable: notifiable
    )
  end

  def unread_notifications_count
    NotificationService.new(self).count_unread_notifications(self)
  end

  # Security Management - Delegate to security service
  def record_failed_login!
    SecurityService.new(self).record_failed_login!
  end

  def record_successful_login!
    SecurityService.new(self).record_successful_login!
  end

  def lock_account!(duration)
    SecurityService.new(self).lock_account!(duration)
  end

  def account_locked?
    SecurityService.new(self).account_locked?
  end

  # Business Intelligence - Delegate to analytics services
  def calculate_customer_lifetime_value(prediction_horizon = :three_years)
    CustomerLifetimeValueService.new(self).calculate(prediction_horizon)
  end

  def generate_user_insights_report(report_context = {})
    UserInsightsService.new(self).generate_report(report_context)
  end

  def total_spent
    OrderAnalyticsService.new(self).calculate_total_spent
  end

  def total_earned
    SellerAnalyticsService.new(self).calculate_total_earned
  end

  # Profile Management - Delegate to profile services
  def profile_completion_percentage
    ProfileService.new(self).calculate_completion_percentage
  end

  def avatar_url_for_display
    AvatarService.new(self).generate_display_url
  end

  def has_feature?(feature_name)
    FeatureService.new(self).check_feature_access(feature_name)
  end

  # ==================== CACHED PERFORMANCE METHODS ====================

  # Cached versions of expensive computations for asymptotic optimality
  def cached_total_spent
    Rails.cache.fetch("user_total_spent_#{id}", expires_in: 1.hour) do
      total_spent
    end
  end

  def cached_unread_notifications_count
    Rails.cache.fetch("user_unread_notifications_#{id}", expires_in: 5.minutes) do
      unread_notifications_count
    end
  end

  def cached_profile_completion_percentage
    Rails.cache.fetch("user_profile_completion_#{id}", expires_in: 30.minutes) do
      profile_completion_percentage
    end
  end

  # ==================== SIMPLE INSTANCE METHODS ====================

  # Type checking methods
  def gem?
    user_type == 'gem'
  end

  def seeker?
    user_type == 'seeker'
  end

  def business?
    user_type == 'business'
  end

  def enterprise?
    user_type == 'enterprise'
  end

  # Permission checking methods
  def can_sell?
    gem? && seller_status_approved?
  end

  def can_access_enterprise_features?
    enterprise? || seller_status_enterprise_verified?
  end

  def can_process_premium_payments?
    identity_verification_status_fully_verified? || identity_verification_status_enterprise_verified?
  end

  # Utility methods
  def level_name
    case level
    when 1 then "Garnet"
    when 2 then "Topaz"
    when 3 then "Emerald"
    when 4 then "Sapphire"
    when 5 then "Ruby"
    when 6 then "Diamond"
    else "Platinum"
    end
  end

  # ==================== PRIVATE METHODS ====================

  private

  def normalize_email
    self.email = email.downcase if email_changed?
  end

  def trigger_essential_post_save_operations
    # Only essential operations - no business logic, with error handling
    begin
      GlobalUserSynchronizationJob.perform_async(id, :update) if saved_changes?
    rescue => e
      Rails.logger.error("Failed to trigger post-save operations for user #{id}: #{e.message}")
      # Optionally, retry or notify
    end
  end

  def execute_user_deactivation_protocol
    begin
      UserDeactivationProtocol.execute(self)
    rescue => e
      Rails.logger.error("User deactivation failed for user #{id}: #{e.message}")
      # Handle gracefully
    end
  end

  def set_default_role
    self.role ||= :user
  end

  def set_default_user_type_and_status
    self.user_type ||= 'seeker'
    self.seller_status ||= 'not_applied'
    self.level ||= 1
    self.identity_verification_status ||= 'unverified'
    self.privacy_level ||= 'private'
  end

  # Cache invalidation for performance
  def invalidate_cache
    Rails.cache.delete("user_total_spent_#{id}")
    Rails.cache.delete("user_unread_notifications_#{id}")
    Rails.cache.delete("user_profile_completion_#{id}")
  end
end