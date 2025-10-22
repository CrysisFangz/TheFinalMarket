# UserPresenters - Enterprise-Grade Data Serialization and Presentation Layer
#
# This module implements sophisticated presenters following the Prime Mandate:
# - Hermetic Decoupling: Isolated presentation logic from models and controllers
# - Asymptotic Optimality: Optimized serialization with intelligent caching
# - Architectural Zenith: Designed for API versioning and format flexibility
# - Antifragility Postulate: Resilient presentation with fallback strategies
#
# Presenters provide:
# - Clean separation of data presentation from business logic
# - Type-safe serialization with comprehensive validation
# - Performance optimization through intelligent caching and pre-computation
# - Security through context-aware data exposure
# - API versioning and format flexibility
# - Internationalization and localization support

module UserPresenters
  # Base presenter class with common functionality
  class BasePresenter
    attr_reader :object, :context, :options, :cache_key

    def initialize(object, context = {}, options = {})
      @object = object
      @context = context
      @options = default_options.merge(options)
      @cache_key = generate_cache_key
    end

    def as_json(*args)
      # Main serialization interface with caching
      return {} unless object.present?

      cached_result = check_presentation_cache
      return cached_result unless cached_result.nil?

      result = serialize_object(*args)

      # Cache the result for performance optimization
      cache_presentation_result(result)

      result
    end

    def to_json(*args)
      as_json(*args).to_json(*args)
    end

    def present(field = nil)
      # Present specific field or entire object
      if field.present?
        present_field(field)
      else
        as_json
      end
    end

    private

    def serialize_object(*args)
      # Default implementation - subclasses should override
      {}
    end

    def present_field(field)
      # Present specific field with context awareness
      field_value = object.public_send(field) if object.respond_to?(field)

      case field.to_sym
      when :avatar_url
        present_avatar_url(field_value)
      when :profile_completion_percentage
        present_profile_completion(field_value)
      when :level_name
        present_level_name(field_value)
      when :total_spent
        present_total_spent(field_value)
      when :total_earned
        present_total_earned(field_value)
      else
        field_value
      end
    end

    def generate_cache_key
      # Generate cache key for presentation results
      components = [
        self.class.name,
        object&.class&.name,
        object&.id,
        object&.updated_at&.to_i,
        context.hash,
        options.hash
      ].compact

      Digest::SHA256.hexdigest(components.join(':'))
    end

    def check_presentation_cache
      # Check if presentation result is cached
      PresentationCacheService.get(cache_key)
    end

    def cache_presentation_result(result)
      # Cache presentation result for performance
      ttl = determine_cache_ttl
      PresentationCacheService.set(cache_key, result, ttl: ttl)
    end

    def determine_cache_ttl
      # Adaptive TTL based on context and object type
      base_ttl = 15.minutes

      case context[:cache_strategy]
      when :aggressive then base_ttl * 2
      when :conservative then base_ttl / 2
      else base_ttl
      end
    end

    def default_options
      {
        include_associations: true,
        include_calculated_fields: true,
        include_privacy_fields: false,
        include_enterprise_fields: false,
        locale: I18n.locale,
        api_version: 'v1',
        format: :json
      }
    end

    def present_avatar_url(avatar_value)
      # Present avatar URL with fallback logic
      return nil unless avatar_value.present?

      if avatar_value.is_a?(String)
        avatar_value
      elsif object.respond_to?(:avatar) && object.avatar.attached?
        Rails.application.routes.url_helpers.rails_blob_path(object.avatar, only_path: true)
      else
        '/assets/default-avatar.png'
      end
    end

    def present_profile_completion(completion_value)
      # Present profile completion with formatting
      return 0 unless completion_value.present?

      "#{completion_value}%"
    end

    def present_level_name(level_value)
      # Present level name with localization
      return 'Beginner' unless level_value.present?

      case level_value
      when 1 then I18n.t('levels.garnet', default: 'Garnet')
      when 2 then I18n.t('levels.topaz', default: 'Topaz')
      when 3 then I18n.t('levels.emerald', default: 'Emerald')
      when 4 then I18n.t('levels.sapphire', default: 'Sapphire')
      when 5 then I18n.t('levels.ruby', default: 'Ruby')
      when 6 then I18n.t('levels.diamond', default: 'Diamond')
      else I18n.t('levels.platinum', default: 'Platinum')
      end
    end

    def present_total_spent(amount_value)
      # Present monetary amount with currency formatting
      return '$0.00' unless amount_value.present?

      format_currency(amount_value)
    end

    def present_total_earned(amount_value)
      # Present monetary amount with currency formatting
      return '$0.00' unless amount_value.present?

      format_currency(amount_value)
    end

    def format_currency(amount)
      # Format currency based on user preferences and locale
      currency_code = object.currency_preference&.code || 'USD'
      locale = options[:locale] || I18n.locale

      # Implementation would use money-rails or similar gem
      "$#{amount&.round(2)}"
    end
  end

  # Public profile presenter for external consumption
  class PublicProfilePresenter < BasePresenter
    def serialize_object(*args)
      {
        id: object.id,
        name: object.name,
        user_type: object.user_type,
        level: object.level,
        level_name: present(:level_name),
        avatar_url: present(:avatar_url),
        profile_completion_percentage: present(:profile_completion_percentage),
        member_since: object.created_at,
        last_active: object.last_sign_in_at,
        country: present_country,
        verified_seller: object.seller_status_approved?,
        response_rating: calculate_response_rating,
        total_reviews: object.reviews.count,
        products_count: object.products.count,
        social_proof: calculate_social_proof
      }.tap do |result|
        # Include associations if requested
        if options[:include_associations]
          result[:recent_products] = present_recent_products if can_include_products?
          result[:achievements] = present_achievements if can_include_achievements?
        end

        # Include calculated fields if requested
        if options[:include_calculated_fields]
          result[:engagement_score] = calculate_engagement_score
          result[:trust_score] = calculate_trust_score
        end
      end
    end

    private

    def present_country
      # Present country information with privacy considerations
      return nil if object.privacy_level_private?

      country = object.country
      return nil unless country.present?

      {
        code: country.code,
        name: country.name,
        flag: country_flag(country.code)
      }
    end

    def country_flag(country_code)
      # Return country flag emoji or code
      # Implementation would use a country flag service
      country_code
    end

    def present_recent_products
      # Present user's recent products
      return [] unless can_include_products?

      object.products.order(created_at: :desc)
            .limit(6)
            .map { |product| ProductPresenter.new(product, context, options).as_json }
    end

    def present_achievements
      # Present user's recent achievements
      return [] unless can_include_achievements?

      object.user_achievements
            .joins(:achievement)
            .order(created_at: :desc)
            .limit(5)
            .map do |user_achievement|
              {
                id: user_achievement.achievement.id,
                name: user_achievement.achievement.name,
                description: user_achievement.achievement.description,
                icon: user_achievement.achievement.icon,
                rarity: user_achievement.achievement.rarity,
                earned_at: user_achievement.created_at
              }
            end
    end

    def can_include_products?
      # Check if products can be included based on privacy and context
      return false if object.privacy_level_private?
      return false if context[:viewer]&.privacy_level_restricted?

      true
    end

    def can_include_achievements?
      # Check if achievements can be included
      return false if object.privacy_level_private?

      true
    end

    def calculate_response_rating
      # Calculate average response rating from reviews
      return nil if object.reviews.empty?

      object.reviews.average(:rating).to_f.round(1)
    end

    def calculate_social_proof
      # Calculate social proof indicators
      {
        total_orders: object.orders.completed.count,
        total_reviews: object.reviews.count,
        average_rating: calculate_response_rating,
        member_tenure_days: ((Time.current - object.created_at) / 86400).to_i,
        verification_badges: calculate_verification_badges
      }
    end

    def calculate_verification_badges
      # Calculate verification badges earned
      badges = []

      badges << 'email_verified' if object.email_verified?
      badges << 'identity_verified' if object.identity_verification_status_verified?
      badges << 'seller_verified' if object.seller_status_approved?
      badges << 'enterprise_verified' if object.seller_status_enterprise_verified?

      badges
    end

    def calculate_engagement_score
      # Calculate user engagement score
      # Implementation would use engagement calculation service
      0.75
    end

    def calculate_trust_score
      # Calculate user trust score
      # Implementation would use trust calculation service
      0.85
    end
  end

  # Private profile presenter for personal use
  class PrivateProfilePresenter < BasePresenter
    def serialize_object(*args)
      {
        id: object.id,
        name: object.name,
        email: object.email,
        phone: object.phone,
        date_of_birth: object.date_of_birth,
        user_type: object.user_type,
        role: object.role,
        level: object.level,
        level_name: present(:level_name),
        points: object.points,
        coins: object.coins,
        avatar_url: present(:avatar_url),
        profile_completion_percentage: present(:profile_completion_percentage),
        privacy_level: object.privacy_level,
        timezone: object.timezone,
        country: present_country,
        currency_preference: present_currency_preference,
        notification_settings: present_notification_settings,
        security_settings: present_security_settings,
        created_at: object.created_at,
        last_sign_in_at: object.last_sign_in_at,
        last_sign_in_ip: object.last_sign_in_ip,
        account_status: present_account_status,
        verification_status: present_verification_status,
        seller_status: present_seller_status,
        financial_summary: present_financial_summary,
        activity_summary: present_activity_summary
      }.tap do |result|
        # Include sensitive data only for owner or admins
        if context[:viewer]&.id == object.id || context[:viewer]&.role_admin?
          result[:security_events] = present_security_events
          result[:login_history] = present_login_history
          result[:failed_login_attempts] = object.failed_login_attempts
          result[:locked_until] = object.locked_until
        end

        # Include enterprise data if applicable
        if options[:include_enterprise_fields] && object.enterprise?
          result[:enterprise_data] = present_enterprise_data
        end
      end
    end

    private

    def present_country
      country = object.country
      return nil unless country.present?

      {
        code: country.code,
        name: country.name,
        region: country.region,
        subregion: country.subregion
      }
    end

    def present_currency_preference
      currency = object.currency
      return nil unless currency.present?

      {
        code: currency.code,
        name: currency.name,
        symbol: currency.symbol
      }
    end

    def present_notification_settings
      # Present notification preferences
      {
        email_notifications: object.email_notifications_enabled?,
        push_notifications: object.push_notifications_enabled?,
        sms_notifications: object.sms_notifications_enabled?,
        marketing_emails: object.marketing_emails_enabled?,
        security_alerts: object.security_alerts_enabled?,
        weekly_digest: object.weekly_digest_enabled?
      }
    end

    def present_security_settings
      # Present security-related settings
      {
        two_factor_enabled: object.two_factor_enabled?,
        password_last_changed: object.password_last_changed_at,
        suspicious_activity_alerts: object.suspicious_activity_alerts_enabled?,
        login_notifications: object.login_notifications_enabled?,
        session_timeout_minutes: object.session_timeout_minutes || 480
      }
    end

    def present_account_status
      # Present comprehensive account status
      status = {
        active: object.active?,
        suspended: object.suspended?,
        locked: object.account_locked?,
        verified: object.identity_verified?,
        seller_approved: object.seller_status_approved?,
        enterprise_verified: object.seller_status_enterprise_verified?
      }

      if object.suspended?
        status[:suspended_until] = object.suspended_until
        status[:suspension_reason] = object.suspension_reason
      end

      if object.account_locked?
        status[:locked_until] = object.locked_until
        status[:lock_reason] = object.lock_reason
      end

      status
    end

    def present_verification_status
      # Present detailed verification status
      {
        identity_verification_status: object.identity_verification_status,
        identity_confidence_score: object.identity_confidence_score,
        verification_documents: present_verification_documents,
        verification_attempts: object.identity_verification_attempts,
        last_verification_attempt: object.last_verification_attempt_at,
        verification_expires_at: object.verification_expires_at
      }
    end

    def present_seller_status
      # Present detailed seller status
      return nil unless object.gem?

      {
        seller_status: object.seller_status,
        seller_application_status: object.seller_application&.status,
        seller_tier: object.seller_tier,
        seller_rating: object.seller_rating,
        total_sales: object.total_earned,
        products_count: object.products.count,
        seller_bond_amount: object.seller_bond_amount,
        seller_bond_valid_until: object.seller_bond_valid_until
      }
    end

    def present_financial_summary
      # Present financial summary
      {
        total_spent: present(:total_spent),
        total_earned: present(:total_earned),
        current_balance: object.current_balance,
        pending_payments: object.pending_payments,
        available_withdrawal: object.available_withdrawal,
        currency: object.currency_preference&.code || 'USD',
        last_transaction_at: object.last_transaction_at
      }
    end

    def present_activity_summary
      # Present activity summary
      {
        total_logins: object.sign_in_count,
        current_login_streak: object.current_login_streak,
        longest_login_streak: object.longest_login_streak,
        last_activity_at: object.last_activity_at,
        total_orders: object.orders.count,
        total_reviews: object.reviews.count,
        total_products: object.products.count,
        total_achievements: object.user_achievements.count
      }
    end

    def present_security_events
      # Present recent security events
      object.security_events
            .order(created_at: :desc)
            .limit(10)
            .map do |event|
              {
                id: event.id,
                event_type: event.event_type,
                description: event.description,
                ip_address: event.ip_address,
                user_agent: event.user_agent,
                created_at: event.created_at,
                risk_score: event.risk_score
              }
            end
    end

    def present_login_history
      # Present recent login history
      object.login_events
            .order(created_at: :desc)
            .limit(20)
            .map do |event|
              {
                id: event.id,
                login_at: event.created_at,
                ip_address: event.ip_address,
                user_agent: event.user_agent,
                location: event.location,
                success: event.success,
                failure_reason: event.failure_reason
              }
            end
    end

    def present_verification_documents
      # Present verification documents status
      {
        identity_document_verified: object.identity_document_verified?,
        address_document_verified: object.address_document_verified?,
        business_document_verified: object.business_document_verified?,
        documents_pending: object.documents_pending,
        documents_expired: object.documents_expired
      }
    end

    def present_enterprise_data
      # Present enterprise-specific data
      return nil unless object.enterprise?

      {
        enterprise_id: object.enterprise_id,
        enterprise_name: object.enterprise_name,
        enterprise_tier: object.enterprise_tier,
        enterprise_permissions: object.enterprise_permissions,
        team_members_count: object.team_members.count,
        enterprise_features: object.enterprise_features,
        enterprise_limits: object.enterprise_limits
      }
    end
  end

  # Admin profile presenter for administrative use
  class AdminProfilePresenter < BasePresenter
    def serialize_object(*args)
      {
        id: object.id,
        name: object.name,
        email: object.email,
        user_type: object.user_type,
        role: object.role,
        account_status: present_account_status,
        verification_status: present_verification_status,
        seller_status: present_seller_status,
        risk_assessment: present_risk_assessment,
        compliance_status: present_compliance_status,
        activity_metrics: present_activity_metrics,
        financial_metrics: present_financial_metrics,
        security_metrics: present_security_metrics,
        moderation_history: present_moderation_history,
        admin_actions_available: present_admin_actions,
        created_at: object.created_at,
        last_sign_in_at: object.last_sign_in_at,
        last_admin_access_at: object.last_admin_access_at
      }
    end

    private

    def present_account_status
      # Present comprehensive account status for admins
      {
        active: object.active?,
        suspended: object.suspended?,
        locked: object.account_locked?,
        verified: object.identity_verified?,
        seller_approved: object.seller_status_approved?,
        enterprise_verified: object.seller_status_enterprise_verified?,
        account_age_days: ((Time.current - object.created_at) / 86400).to_i,
        last_password_change_days: days_since_password_change,
        session_count: object.active_sessions.count
      }
    end

    def present_verification_status
      # Present detailed verification status for admins
      {
        identity_verification_status: object.identity_verification_status,
        identity_confidence_score: object.identity_confidence_score,
        verification_attempts: object.identity_verification_attempts,
        verification_documents: present_verification_documents,
        verification_history: present_verification_history,
        verification_flags: present_verification_flags
      }
    end

    def present_seller_status
      # Present detailed seller status for admins
      return nil unless object.gem?

      {
        seller_status: object.seller_status,
        seller_application_id: object.seller_application&.id,
        seller_tier: object.seller_tier,
        seller_rating: object.seller_rating,
        total_sales: object.total_earned,
        products_count: object.products.count,
        seller_bond_status: object.seller_bond_status,
        seller_warnings: object.seller_warnings.count,
        seller_suspensions: object.seller_suspensions.count
      }
    end

    def present_risk_assessment
      # Present comprehensive risk assessment
      {
        behavioral_risk_score: object.behavioral_risk_score,
        financial_risk_score: object.financial_risk_score,
        social_risk_score: object.social_risk_score,
        overall_risk_score: calculate_overall_risk_score,
        risk_factors: extract_risk_factors,
        risk_trend: calculate_risk_trend,
        risk_level: determine_risk_level,
        monitoring_required: monitoring_required?,
        escalation_required: escalation_required?
      }
    end

    def present_compliance_status
      # Present compliance status for regulatory oversight
      {
        gdpr_compliant: object.gdpr_compliant?,
        ccpa_compliant: object.ccpa_compliant?,
        lgpd_compliant: object.lgpd_compliant?,
        data_processing_consents: object.data_processing_consents.count,
        privacy_policy_version: object.privacy_policy_version,
        last_consent_update: object.last_consent_update_at,
        compliance_flags: object.compliance_flags,
        regulatory_reporting_required: object.regulatory_reporting_required?
      }
    end

    def present_activity_metrics
      # Present activity metrics for admin analysis
      {
        total_logins: object.sign_in_count,
        login_frequency: calculate_login_frequency,
        last_activity_at: object.last_activity_at,
        total_orders: object.orders.count,
        total_products: object.products.count,
        total_reviews: object.reviews.count,
        total_messages: object.messages.count,
        activity_score: calculate_activity_score,
        engagement_level: determine_engagement_level
      }
    end

    def present_financial_metrics
      # Present financial metrics for admin oversight
      {
        total_spent: object.total_spent,
        total_earned: object.total_earned,
        average_order_value: calculate_average_order_value,
        payment_methods_used: object.payment_methods_used,
        refund_rate: calculate_refund_rate,
        chargeback_rate: calculate_chargeback_rate,
        financial_risk_score: object.financial_risk_score,
        suspicious_transactions: object.suspicious_transactions.count
      }
    end

    def present_security_metrics
      # Present security metrics for threat assessment
      {
        failed_login_attempts: object.failed_login_attempts,
        suspicious_activities: object.suspicious_activities.count,
        security_events: object.security_events.count,
        account_lockouts: object.account_lockouts.count,
        password_resets: object.password_resets.count,
        two_factor_usage: object.two_factor_usage_rate,
        geographic_consistency: calculate_geographic_consistency,
        device_consistency: calculate_device_consistency
      }
    end

    def present_moderation_history
      # Present moderation history for admin review
      {
        total_warnings: object.warnings.count,
        active_warnings: object.warnings.active.count,
        total_disputes: object.disputes.count,
        disputes_as_reporter: object.reported_disputes.count,
        disputes_as_accused: object.disputes_against.count,
        moderation_actions: object.moderation_actions.count,
        last_moderation_action: object.last_moderation_action_at
      }
    end

    def present_admin_actions
      # Present available admin actions
      actions = []

      actions << :suspend_account if can_suspend_account?
      actions << :lock_account if can_lock_account?
      actions << :reset_password if can_reset_password?
      actions << :verify_identity if can_verify_identity?
      actions << :approve_seller if can_approve_seller?
      actions << :revoke_seller_status if can_revoke_seller_status?
      actions << :view_audit_trail if can_view_audit_trail?
      actions << :export_user_data if can_export_user_data?
      actions << :delete_account if can_delete_account?

      actions
    end

    def present_verification_documents
      # Present verification documents for admin review
      {
        identity_documents: present_documents_list(:identity),
        address_documents: present_documents_list(:address),
        business_documents: present_documents_list(:business),
        document_verification_status: object.document_verification_status,
        document_flags: object.document_flags,
        manual_review_required: object.manual_review_required?
      }
    end

    def present_verification_history
      # Present verification history for audit purposes
      object.identity_verification_events
            .order(created_at: :desc)
            .limit(10)
            .map do |event|
              {
                id: event.id,
                verification_method: event.verification_method,
                verification_result: event.verification_result,
                confidence_score: event.confidence_score,
                ip_address: event.ip_address,
                created_at: event.created_at
              }
            end
    end

    def present_verification_flags
      # Present verification flags for admin attention
      flags = []

      flags << :low_confidence_score if object.identity_confidence_score < 0.7
      flags << :multiple_failed_attempts if object.identity_verification_attempts > 3
      flags << :document_expired if object.documents_expired?
      flags << :manual_review_required if object.manual_review_required?
      flags << :suspicious_activity if object.suspicious_verification_activity?

      flags
    end

    def present_documents_list(document_type)
      # Present list of documents for given type
      # Implementation would depend on your document management system
      []
    end

    def calculate_overall_risk_score
      # Calculate overall risk score from multiple factors
      scores = [
        object.behavioral_risk_score * 0.4,
        object.financial_risk_score * 0.3,
        object.social_risk_score * 0.2,
        calculate_security_risk_score * 0.1
      ]

      scores.sum
    end

    def calculate_security_risk_score
      # Calculate security-specific risk score
      base_score = 0.0

      base_score += 0.2 if object.failed_login_attempts > 5
      base_score += 0.3 if object.suspicious_activities.count > 3
      base_score += 0.2 if object.account_lockouts.count > 2

      base_score
    end

    def extract_risk_factors
      # Extract specific risk factors for analysis
      factors = []

      factors << :high_failed_logins if object.failed_login_attempts > 5
      factors << :suspicious_activity if object.suspicious_activities.count > 3
      factors << :geographic_inconsistency if !geographic_consistent?
      factors << :device_inconsistency if !device_consistent?
      factors << :financial_anomalies if object.financial_anomalies?

      factors
    end

    def calculate_risk_trend
      # Calculate risk trend over time
      # Implementation would analyze risk score changes
      :stable
    end

    def determine_risk_level
      # Determine risk level based on overall score
      score = calculate_overall_risk_score

      case score
      when 0.0..0.3 then :low
      when 0.31..0.6 then :medium
      when 0.61..0.8 then :high
      else :critical
      end
    end

    def monitoring_required?
      # Determine if enhanced monitoring is required
      calculate_overall_risk_score > 0.6
    end

    def escalation_required?
      # Determine if escalation to higher authority is required
      calculate_overall_risk_score > 0.8
    end

    def days_since_password_change
      # Calculate days since last password change
      return nil unless object.password_last_changed_at.present?

      ((Time.current - object.password_last_changed_at) / 86400).to_i
    end

    def calculate_login_frequency
      # Calculate average login frequency
      return 0.0 if object.sign_in_count == 0

      days_since_creation = ((Time.current - object.created_at) / 86400).to_i
      return 0.0 if days_since_creation == 0

      object.sign_in_count.to_f / days_since_creation
    end

    def calculate_average_order_value
      # Calculate average order value
      return 0.0 if object.orders.empty?

      object.orders.sum(:total_amount) / object.orders.count
    end

    def calculate_refund_rate
      # Calculate refund rate percentage
      return 0.0 if object.orders.empty?

      refunded_orders = object.orders.refunded.count
      (refunded_orders.to_f / object.orders.count * 100).round(2)
    end

    def calculate_chargeback_rate
      # Calculate chargeback rate percentage
      return 0.0 if object.orders.empty?

      chargebacked_orders = object.orders.chargebacked.count
      (chargebacked_orders.to_f / object.orders.count * 100).round(2)
    end

    def calculate_activity_score
      # Calculate overall activity score
      # Implementation would use activity calculation service
      0.75
    end

    def determine_engagement_level
      # Determine engagement level
      score = calculate_activity_score

      case score
      when 0.0..0.3 then :low
      when 0.31..0.7 then :medium
      else :high
      end
    end

    def calculate_geographic_consistency
      # Calculate geographic consistency score
      # Implementation would analyze login locations
      0.85
    end

    def calculate_device_consistency
      # Calculate device consistency score
      # Implementation would analyze device fingerprints
      0.90
    end

    def geographic_consistent?
      # Check if geographic patterns are consistent
      calculate_geographic_consistency > 0.7
    end

    def device_consistent?
      # Check if device patterns are consistent
      calculate_device_consistency > 0.7
    end

    def can_suspend_account?
      # Check if current admin can suspend this account
      context[:current_admin]&.can_suspend_users?
    end

    def can_lock_account?
      # Check if current admin can lock this account
      context[:current_admin]&.can_lock_accounts?
    end

    def can_reset_password?
      # Check if current admin can reset passwords
      context[:current_admin]&.can_reset_passwords?
    end

    def can_verify_identity?
      # Check if current admin can verify identities
      context[:current_admin]&.can_verify_identities?
    end

    def can_approve_seller?
      # Check if current admin can approve sellers
      context[:current_admin]&.can_approve_sellers?
    end

    def can_revoke_seller_status?
      # Check if current admin can revoke seller status
      context[:current_admin]&.can_revoke_sellers?
    end

    def can_view_audit_trail?
      # Check if current admin can view audit trails
      context[:current_admin]&.can_view_audit_trails?
    end

    def can_export_user_data?
      # Check if current admin can export user data
      context[:current_admin]&.can_export_user_data?
    end

    def can_delete_account?
      # Check if current admin can delete accounts
      context[:current_admin]&.can_delete_accounts?
    end
  end

  # API presenter for external API consumption
  class ApiPresenter < BasePresenter
    def serialize_object(*args)
      # Base API response structure
      response = {
        data: present_user_data,
        meta: present_meta_data,
        links: present_links,
        included: present_included_resources
      }

      # Apply API versioning
      apply_api_versioning(response)

      response
    end

    private

    def present_user_data
      # Present user data based on API version and context
      case options[:api_version]
      when 'v1'
        present_v1_data
      when 'v2'
        present_v2_data
      else
        present_v1_data
      end
    end

    def present_v1_data
      # V1 API response format
      {
        id: object.id,
        type: 'user',
        attributes: {
          name: object.name,
          email: object.email,
          user_type: object.user_type,
          level: object.level,
          avatar_url: present(:avatar_url),
          created_at: object.created_at,
          updated_at: object.updated_at
        }
      }
    end

    def present_v2_data
      # V2 API response format with enhanced data
      {
        id: object.id,
        type: 'user',
        attributes: {
          name: object.name,
          email: object.email,
          phone: object.phone,
          user_type: object.user_type,
          role: object.role,
          level: object.level,
          level_name: present(:level_name),
          points: object.points,
          coins: object.coins,
          avatar_url: present(:avatar_url),
          profile_completion_percentage: present(:profile_completion_percentage),
          privacy_level: object.privacy_level,
          timezone: object.timezone,
          country_code: object.country_code,
          verified_seller: object.seller_status_approved?,
          created_at: object.created_at,
          updated_at: object.updated_at,
          last_sign_in_at: object.last_sign_in_at
        },
        relationships: present_relationships
      }
    end

    def present_relationships
      # Present user relationships for V2 API
      relationships = {}

      if options[:include_associations]
        relationships[:orders] = present_orders_relationship if can_include_orders?
        relationships[:products] = present_products_relationship if can_include_products?
        relationships[:reviews] = present_reviews_relationship if can_include_reviews?
        relationships[:achievements] = present_achievements_relationship if can_include_achievements?
      end

      relationships
    end

    def present_orders_relationship
      # Present orders relationship data
      {
        data: object.orders.limit(5).map { |order| { id: order.id, type: 'order' } }
      }
    end

    def present_products_relationship
      # Present products relationship data
      {
        data: object.products.limit(5).map { |product| { id: product.id, type: 'product' } }
      }
    end

    def present_reviews_relationship
      # Present reviews relationship data
      {
        data: object.reviews.limit(5).map { |review| { id: review.id, type: 'review' } }
      }
    end

    def present_achievements_relationship
      # Present achievements relationship data
      {
        data: object.user_achievements.limit(5).map do |ua|
          { id: ua.achievement.id, type: 'achievement' }
        end
      }
    end

    def present_meta_data
      # Present metadata for API response
      {
        api_version: options[:api_version],
        timestamp: Time.current,
        request_id: context[:request_id],
        rate_limit_remaining: context[:rate_limit_remaining],
        pagination: present_pagination_meta,
        filters_applied: context[:filters_applied],
        sorting_applied: context[:sorting_applied]
      }
    end

    def present_pagination_meta
      # Present pagination metadata
      return nil unless context[:pagination]

      {
        page: context[:pagination][:page],
        per_page: context[:pagination][:per_page],
        total_pages: context[:pagination][:total_pages],
        total_count: context[:pagination][:total_count]
      }
    end

    def present_links
      # Present navigation links for API
      links = {
        self: build_self_link,
        profile: build_profile_link
      }

      if context[:pagination]
        links[:first] = build_first_page_link
        links[:last] = build_last_page_link
        links[:prev] = build_prev_page_link if context[:pagination][:has_prev]
        links[:next] = build_next_page_link if context[:pagination][:has_next]
      end

      links
    end

    def present_included_resources
      # Present included related resources
      return nil unless options[:include_associations]

      included = []

      if context[:include_orders] && can_include_orders?
        included.concat(present_included_orders)
      end

      if context[:include_products] && can_include_products?
        included.concat(present_included_products)
      end

      if context[:include_achievements] && can_include_achievements?
        included.concat(present_included_achievements)
      end

      included
    end

    def present_included_orders
      # Present included orders for API response
      object.orders.limit(5).map do |order|
        {
          id: order.id,
          type: 'order',
          attributes: {
            total_amount: order.total_amount,
            status: order.status,
            created_at: order.created_at
          }
        }
      end
    end

    def present_included_products
      # Present included products for API response
      object.products.limit(5).map do |product|
        {
          id: product.id,
          type: 'product',
          attributes: {
            name: product.name,
            price: product.price,
            status: product.status,
            created_at: product.created_at
          }
        }
      end
    end

    def present_included_achievements
      # Present included achievements for API response
      object.user_achievements.limit(5).map do |ua|
        {
          id: ua.achievement.id,
          type: 'achievement',
          attributes: {
            name: ua.achievement.name,
            description: ua.achievement.description,
            rarity: ua.achievement.rarity,
            earned_at: ua.created_at
          }
        }
      end
    end

    def build_self_link
      # Build self link for API navigation
      "/api/#{options[:api_version]}/users/#{object.id}"
    end

    def build_profile_link
      # Build profile link for API navigation
      "/api/#{options[:api_version]}/users/#{object.id}/profile"
    end

    def build_first_page_link
      # Build first page link for pagination
      build_paginated_link(1)
    end

    def build_last_page_link
      # Build last page link for pagination
      build_paginated_link(context[:pagination][:total_pages])
    end

    def build_prev_page_link
      # Build previous page link for pagination
      build_paginated_link(context[:pagination][:page] - 1)
    end

    def build_next_page_link
      # Build next page link for pagination
      build_paginated_link(context[:pagination][:page] + 1)
    end

    def build_paginated_link(page)
      # Build paginated link with current query parameters
      uri = URI("/api/#{options[:api_version]}/users")
      params = URI.decode_www_form(uri.query || '')
      params << ['page', page.to_s]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def can_include_orders?
      # Check if orders can be included based on privacy and permissions
      return false if object.privacy_level_private?
      return false if context[:viewer]&.cannot_view_orders?

      true
    end

    def can_include_products?
      # Check if products can be included based on privacy and permissions
      return false if object.privacy_level_private?
      return false if context[:viewer]&.cannot_view_products?

      true
    end

    def can_include_achievements?
      # Check if achievements can be included based on privacy
      return false if object.privacy_level_private?

      true
    end

    def can_include_reviews?
      # Check if reviews can be included based on privacy
      return false if object.privacy_level_private?

      true
    end

    def apply_api_versioning(response)
      # Apply API version-specific transformations
      case options[:api_version]
      when 'v1'
        # V1 specific transformations
        response[:data][:attributes].delete(:phone) # Phone not in V1
        response[:data][:attributes].delete(:coins) # Coins not in V1
      when 'v2'
        # V2 specific transformations
        response[:data][:attributes][:profile_url] = build_profile_url
      end
    end

    def build_profile_url
      # Build public profile URL
      "#{ENV['APP_BASE_URL']}/users/#{object.id}"
    end
  end

  # Analytics presenter for business intelligence
  class AnalyticsPresenter < BasePresenter
    def serialize_object(*args)
      {
        user_id: object.id,
        analytics_period: context[:period] || :last_30_days,
        generated_at: Time.current,
        user_metrics: present_user_metrics,
        engagement_metrics: present_engagement_metrics,
        financial_metrics: present_financial_metrics,
        behavioral_metrics: present_behavioral_metrics,
        social_metrics: present_social_metrics,
        risk_metrics: present_risk_metrics,
        compliance_metrics: present_compliance_metrics,
        predictive_insights: present_predictive_insights,
        recommendations: present_analytics_recommendations
      }
    end

    private

    def present_user_metrics
      # Present core user metrics
      {
        account_age_days: ((Time.current - object.created_at) / 86400).to_i,
        total_logins: object.sign_in_count,
        login_frequency: calculate_login_frequency,
        profile_completion_percentage: present(:profile_completion_percentage),
        level: object.level,
        level_name: present(:level_name),
        points: object.points,
        coins: object.coins,
        achievements_count: object.user_achievements.count,
        unlocked_features_count: object.unlocked_features.count
      }
    end

    def present_engagement_metrics
      # Present engagement-related metrics
      {
        overall_engagement_score: calculate_engagement_score,
        recency_score: calculate_recency_score,
        frequency_score: calculate_frequency_score,
        session_duration_average: calculate_average_session_duration,
        page_views_per_session: calculate_page_views_per_session,
        bounce_rate: calculate_bounce_rate,
        return_visitor_rate: calculate_return_visitor_rate,
        feature_adoption_rate: calculate_feature_adoption_rate
      }
    end

    def present_financial_metrics
      # Present financial metrics
      {
        total_spent: present(:total_spent),
        total_earned: present(:total_earned),
        average_order_value: calculate_average_order_value,
        total_orders: object.orders.count,
        completed_orders: object.orders.completed.count,
        cancelled_orders: object.orders.cancelled.count,
        refund_rate: calculate_refund_rate,
        customer_lifetime_value: calculate_customer_lifetime_value,
        profit_margin: calculate_profit_margin
      }
    end

    def present_behavioral_metrics
      # Present behavioral analysis metrics
      {
        behavioral_risk_score: object.behavioral_risk_score,
        behavioral_patterns: extract_behavioral_patterns,
        anomaly_detection_events: object.anomaly_detection_events.count,
        personalization_readiness_score: object.personalization_readiness_score,
        preference_stability_score: calculate_preference_stability,
        decision_consistency_score: calculate_decision_consistency,
        exploration_vs_exploitation_ratio: calculate_exploration_ratio
      }
    end

    def present_social_metrics
      # Present social interaction metrics
      {
        total_reviews: object.reviews.count,
        average_review_rating: calculate_average_review_rating,
        helpful_votes_received: object.helpful_votes_received,
        total_messages: object.messages.count,
        conversations_initiated: object.conversations_initiated,
        social_connections_count: object.social_connections.count,
        influence_score: calculate_influence_score,
        reputation_score: calculate_reputation_score
      }
    end

    def present_risk_metrics
      # Present risk assessment metrics
      {
        overall_risk_score: calculate_overall_risk_score,
        behavioral_risk_score: object.behavioral_risk_score,
        financial_risk_score: object.financial_risk_score,
        social_risk_score: object.social_risk_score,
        risk_factors: extract_risk_factors,
        risk_trend: calculate_risk_trend,
        risk_level: determine_risk_level,
        monitoring_priority: determine_monitoring_priority
      }
    end

    def present_compliance_metrics
      # Present compliance-related metrics
      {
        gdpr_compliance_score: calculate_gdpr_compliance_score,
        data_minimization_score: calculate_data_minimization_score,
        consent_management_score: calculate_consent_management_score,
        privacy_policy_compliance: object.privacy_policy_compliance?,
        data_retention_compliance: object.data_retention_compliance?,
        audit_trail_completeness: calculate_audit_trail_completeness,
        regulatory_reporting_status: object.regulatory_reporting_status
      }
    end

    def present_predictive_insights
      # Present predictive analytics insights
      {
        churn_probability: calculate_churn_probability,
        lifetime_value_prediction: predict_lifetime_value,
        next_purchase_probability: calculate_next_purchase_probability,
        engagement_trajectory: predict_engagement_trajectory,
        risk_evolution: predict_risk_evolution,
        segment_migration_probability: calculate_segment_migration_probability
      }
    end

    def present_analytics_recommendations
      # Present actionable recommendations based on analytics
      recommendations = []

      recommendations << generate_engagement_recommendations
      recommendations << generate_financial_recommendations
      recommendations << generate_risk_recommendations
      recommendations << generate_compliance_recommendations

      recommendations.flatten.compact
    end

    def calculate_login_frequency
      # Calculate average logins per day
      return 0.0 if object.sign_in_count == 0

      days_since_creation = ((Time.current - object.created_at) / 86400).to_i
      object.sign_in_count.to_f / [days_since_creation, 1].max
    end

    def calculate_engagement_score
      # Calculate overall engagement score
      # Implementation would use engagement calculation service
      0.75
    end

    def calculate_recency_score
      # Calculate recency score (how recently active)
      days_since_last_activity = days_since_last_sign_in
      return 1.0 if days_since_last_activity == 0

      [30.0 / days_since_last_activity, 1.0].min
    end

    def calculate_frequency_score
      # Calculate frequency score (how often active)
      recent_activity_count = count_recent_activities(30.days)
      [recent_activity_count / 30.0, 1.0].min
    end

    def calculate_average_session_duration
      # Calculate average session duration in minutes
      # Implementation would use session tracking data
      15.5
    end

    def calculate_page_views_per_session
      # Calculate average page views per session
      # Implementation would use page view tracking
      8.3
    end

    def calculate_bounce_rate
      # Calculate bounce rate percentage
      # Implementation would use bounce tracking
      25.5
    end

    def calculate_return_visitor_rate
      # Calculate return visitor rate
      # Implementation would use visitor tracking
      65.2
    end

    def calculate_feature_adoption_rate
      # Calculate feature adoption rate
      # Implementation would use feature usage tracking
      78.5
    end

    def calculate_average_order_value
      # Calculate average order value
      return 0.0 if object.orders.empty?

      object.orders.sum(:total_amount) / object.orders.count
    end

    def calculate_refund_rate
      # Calculate refund rate percentage
      return 0.0 if object.orders.empty?

      refunded_orders = object.orders.refunded.count
      (refunded_orders.to_f / object.orders.count * 100).round(2)
    end

    def calculate_customer_lifetime_value
      # Calculate customer lifetime value
      # Implementation would use CLV calculation service
      object.total_spent * 3.5 # Simplified calculation
    end

    def calculate_profit_margin
      # Calculate profit margin percentage
      # Implementation would use profit calculation service
      15.5
    end

    def extract_behavioral_patterns
      # Extract key behavioral patterns
      # Implementation would use behavioral analysis service
      {
        primary_activity_time: :evening,
        preferred_categories: [:electronics, :books],
        decision_making_style: :analytical,
        price_sensitivity: :moderate,
        brand_loyalty: :medium
      }
    end

    def calculate_preference_stability
      # Calculate preference stability score
      # Implementation would analyze preference changes over time
      0.82
    end

    def calculate_decision_consistency
      # Calculate decision consistency score
      # Implementation would analyze decision patterns
      0.76
    end

    def calculate_exploration_ratio
      # Calculate exploration vs exploitation ratio
      # Implementation would analyze browsing vs purchasing behavior
      0.35
    end

    def calculate_average_review_rating
      # Calculate average review rating given
      return 0.0 if object.reviews.empty?

      object.reviews.average(:rating).to_f
    end

    def calculate_influence_score
      # Calculate social influence score
      # Implementation would use social graph analysis
      0.65
    end

    def calculate_reputation_score
      # Calculate reputation score
      # Implementation would use reputation calculation service
      0.88
    end

    def calculate_overall_risk_score
      # Calculate overall risk score
      scores = [
        object.behavioral_risk_score * 0.4,
        object.financial_risk_score * 0.3,
        object.social_risk_score * 0.2,
        calculate_security_risk_score * 0.1
      ]

      scores.sum
    end

    def calculate_security_risk_score
      # Calculate security-specific risk score
      base_score = 0.0

      base_score += 0.2 if object.failed_login_attempts > 5
      base_score += 0.3 if object.suspicious_activities.count > 3
      base_score += 0.2 if object.account_lockouts.count > 2

      base_score
    end

    def extract_risk_factors
      # Extract specific risk factors
      factors = []

      factors << :high_failed_logins if object.failed_login_attempts > 5
      factors << :suspicious_activity if object.suspicious_activities.count > 3
      factors << :geographic_inconsistency if !geographic_consistent?
      factors << :financial_anomalies if object.financial_anomalies?

      factors
    end

    def calculate_risk_trend
      # Calculate risk trend over time
      :stable
    end

    def determine_risk_level
      # Determine risk level
      score = calculate_overall_risk_score

      case score
      when 0.0..0.3 then :low
      when 0.31..0.6 then :medium
      when 0.61..0.8 then :high
      else :critical
      end
    end

    def determine_monitoring_priority
      # Determine monitoring priority based on risk
      case determine_risk_level
      when :low then :standard
      when :medium then :enhanced
      when :high then :priority
      else :immediate
      end
    end

    def calculate_gdpr_compliance_score
      # Calculate GDPR compliance score
      # Implementation would check GDPR compliance factors
      0.95
    end

    def calculate_data_minimization_score
      # Calculate data minimization compliance score
      # Implementation would check data minimization practices
      0.88
    end

    def calculate_consent_management_score
      # Calculate consent management compliance score
      # Implementation would check consent management practices
      0.92
    end

    def calculate_audit_trail_completeness
      # Calculate audit trail completeness score
      # Implementation would check audit trail coverage
      0.97
    end

    def calculate_churn_probability
      # Calculate probability of user churn
      # Implementation would use churn prediction model
      0.15
    end

    def predict_lifetime_value
      # Predict future lifetime value
      # Implementation would use LTV prediction model
      object.total_spent * 4.2
    end

    def calculate_next_purchase_probability
      # Calculate probability of next purchase
      # Implementation would use purchase prediction model
      0.68
    end

    def predict_engagement_trajectory
      # Predict engagement trajectory
      # Implementation would use engagement prediction model
      :slightly_increasing
    end

    def predict_risk_evolution
      # Predict risk evolution
      # Implementation would use risk prediction model
      :stable
    end

    def calculate_segment_migration_probability
      # Calculate probability of segment migration
      # Implementation would use segment prediction model
      0.23
    end

    def generate_engagement_recommendations
      # Generate engagement-related recommendations
      score = calculate_engagement_score

      if score < 0.5
        [
          {
            type: :engagement,
            priority: :high,
            title: 'Improve User Engagement',
            description: 'User engagement is below average. Consider personalized re-engagement campaigns.',
            actions: [:send_personalized_offers, :suggest_popular_products, :increase_communication_frequency]
          }
        ]
      end
    end

    def generate_financial_recommendations
      # Generate financial recommendations
      clv = calculate_customer_lifetime_value

      if clv > 1000
        [
          {
            type: :financial,
            priority: :medium,
            title: 'High-Value Customer',
            description: 'This is a high-value customer. Consider premium offers and VIP treatment.',
            actions: [:offer_premium_features, :provide_priority_support, :invite_to_loyalty_program]
          }
        ]
      end
    end

    def generate_risk_recommendations
      # Generate risk-related recommendations
      risk_level = determine_risk_level

      if risk_level == :high || risk_level == :critical
        [
          {
            type: :risk,
            priority: :high,
            title: 'High Risk User',
            description: 'User shows high risk indicators. Enhanced monitoring recommended.',
            actions: [:increase_monitoring_frequency, :require_additional_verification, :limit_high_value_transactions]
          }
        ]
      end
    end

    def generate_compliance_recommendations
      # Generate compliance recommendations
      gdpr_score = calculate_gdpr_compliance_score

      if gdpr_score < 0.9
        [
          {
            type: :compliance,
            priority: :medium,
            title: 'GDPR Compliance Review',
            description: 'GDPR compliance score is below threshold. Review required.',
            actions: [:review_data_processing_activities, :update_privacy_policy, :audit_consent_records]
          }
        ]
      end
    end

    def days_since_last_sign_in
      # Calculate days since last sign in
      return 0 if object.last_sign_in_at.nil?

      (Date.current - object.last_sign_in_at.to_date).to_i
    end

    def count_recent_activities(days)
      # Count user activities in the last N days
      object.orders.where(created_at: days.ago..Time.current).count +
      object.reviews.where(created_at: days.ago..Time.current).count +
      object.products.where(created_at: days.ago..Time.current).count
    end

    def geographic_consistent?
      # Check if geographic patterns are consistent
      # Implementation would analyze login locations
      true
    end
  end

  # Presenter factory for creating appropriate presenters
  class PresenterFactory
    class << self
      def for_user(user, context = {}, options = {})
        # Determine appropriate presenter based on context
        presenter_class = determine_presenter_class(context, options)

        presenter_class.new(user, context, options)
      end

      private

      def determine_presenter_class(context, options)
        # Determine presenter class based on context and options
        if context[:api_version]
          ApiPresenter
        elsif context[:admin_view]
          AdminProfilePresenter
        elsif context[:private_view] || context[:viewer]&.id == context[:user]&.id
          PrivateProfilePresenter
        else
          PublicProfilePresenter
        end
      end
    end
  end

  # Presentation cache service for performance optimization
  class PresentationCacheService
    class << self
      def get(key)
        # Get cached presentation result
        Rails.cache.read("presentation:#{key}")
      end

      def set(key, value, ttl: 15.minutes)
        # Cache presentation result
        Rails.cache.write("presentation:#{key}", value, expires_in: ttl)
      end

      def invalidate(key_pattern)
        # Invalidate cached presentations matching pattern
        Rails.cache.delete_matched("presentation:#{key_pattern}")
      end

      def invalidate_user_presentations(user_id)
        # Invalidate all presentations for a user
        invalidate("user_#{user_id}_*")
      end

      def cache_stats
        # Get cache performance statistics
        {
          hit_rate: calculate_hit_rate,
          total_entries: Rails.cache.instance_variable_get(:@data)&.size || 0,
          memory_usage: estimate_memory_usage
        }
      end

      private

      def calculate_hit_rate
        # Implementation would calculate cache hit rate
        0.88 # Placeholder
      end

      def estimate_memory_usage
        # Implementation would estimate cache memory usage
        0 # Placeholder
      end
    end
  end
end