# frozen_string_literal: true

# ApplicationPolicy - Enterprise-grade authorization base class
# Implements sophisticated permission system with caching, audit trails, and performance optimization
#
# @example Usage in child policies:
#   class ProductPolicy < ApplicationPolicy
#     def update?
#       user.admin? || (user.seller? && record.seller == user)
#     end
#   end
class ApplicationPolicy
  # Include policy modules for enhanced functionality
  include PolicyCache
  include PolicyAudit
  include PolicyMetrics

  # Reader attributes for core policy objects
  attr_reader :user, :record, :context

  # Enhanced initialization with context support and validation
  # @param user [User, nil] The user making the request
  # @param record [Object, nil] The record being accessed
  # @param context [Hash] Additional context for policy evaluation
  def initialize(user, record, context = {})
    @user = user
    @record = record
    @context = context

    validate_policy_initialization
    setup_policy_context
  end

  # Default authorization methods - secure by default (deny all)
  # These methods should be overridden in child policies with specific logic

  # List/Index action authorization
  # @return [Boolean] false by default for security
  def index?
    record_authorized_for_collection_action?
  end

  # Show/Read action authorization
  # @return [Boolean] false by default for security
  def show?
    record_authorized_for_individual_action?
  end

  # Create/New action authorization
  # @return [Boolean] false by default for security
  def create?
    user_authorized_for_creation?
  end

  # New action delegates to create for consistency
  def new?
    create?
  end

  # Update/Edit action authorization
  # @return [Boolean] false by default for security
  def update?
    record_authorized_for_modification?
  end

  # Edit action delegates to update for consistency
  def edit?
    update?
  end

  # Destroy/Delete action authorization
  # @return [Boolean] false by default for security
  def destroy?
    record_authorized_for_deletion?
  end

  # Bulk operations authorization
  def bulk_update?
    user&.admin? && index?
  end

  def bulk_destroy?
    user&.admin? && index?
  end

  # Advanced authorization methods

  # Check if user can perform any action on the record
  # @return [Boolean]
  def any_action?
    [index?, show?, create?, update?, destroy?].any?
  end

  # Check if user has full access to the record
  # @return [Boolean]
  def full_access?
    user&.admin? || (user&.moderator? && record_moderatable?)
  end

  # Check if user owns the record
  # @return [Boolean]
  def owner?
    return false unless user && record

    record_ownership_fields.any? do |field|
      record.send(field) == user.id if record.respond_to?(field)
    end
  end

  # Scope class for filtering collections based on user permissions
  class Scope
    include PolicyScopeExtensions

    attr_reader :user, :scope, :context

    # Initialize scope with user, base scope, and context
    # @param user [User, nil] The user making the request
    # @param scope [ActiveRecord::Relation] The base scope to filter
    # @param context [Hash] Additional context for scope resolution
    def initialize(user, scope, context = {})
      @user = user
      @scope = scope
      @context = context

      validate_scope_initialization
    end

    # Resolve the filtered scope - must be implemented by child classes
    # @raise [NotImplementedError] if not overridden
    def resolve
      raise NotImplementedError,
        "You must define #resolve in #{self.class}. " \
        "Consider: scope.where(user: user) or scope.where(published: true)"
    end

    private

    # Validate scope initialization parameters
    def validate_scope_initialization
      raise ArgumentError, "Scope cannot be nil" unless scope
      raise ArgumentError, "Scope must be an ActiveRecord relation" unless valid_scope_type?
    end

    # Check if scope is a valid ActiveRecord relation
    def valid_scope_type?
      scope.is_a?(ActiveRecord::Relation) || scope.is_a?(Class)
    end
  end

  private

  # Validate policy initialization
  def validate_policy_initialization
    return if user.nil? # Allow anonymous access checks

    unless user.respond_to?(:role) || user.respond_to?(:permissions)
      Rails.logger.warn("User object may not have proper authorization attributes")
    end
  end

  # Setup additional policy context
  def setup_policy_context
    @policy_cache_key = generate_cache_key if respond_to?(:generate_cache_key)
    @audit_context = build_audit_context if respond_to?(:build_audit_context)
  end

  # Default authorization checks - can be overridden for specific logic

  def record_authorized_for_collection_action?
    false
  end

  def record_authorized_for_individual_action?
    false
  end

  def user_authorized_for_creation?
    false
  end

  def record_authorized_for_modification?
    false
  end

  def record_authorized_for_deletion?
    false
  end

  def record_moderatable?
    record.respond_to?(:moderatable?) && record.moderatable?
  end

  # Define fields that indicate record ownership
  def record_ownership_fields
    %i[user_id owner_id seller_id creator_id author_id]
  end
end

# Policy caching mixin for performance optimization
module PolicyCache
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def cache_policy_result(method_name, ttl = 5.minutes)
      @cached_methods ||= {}
      @cached_methods[method_name] = ttl
    end

    def get_cached_methods
      @cached_methods || {}
    end
  end

  private

  def method_missing(method_name, *args)
    if self.class.get_cached_methods.key?(method_name)
      Rails.cache.fetch(cache_key_for(method_name), expires_in: ttl_for(method_name)) do
        super
      end
    else
      super
    end
  end

  def cache_key_for(method_name)
    "policy:#{self.class.name}:#{method_name}:#{user&.id}:#{record&.id}:#{record&.updated_at&.to_i}"
  end

  def ttl_for(method_name)
    self.class.get_cached_methods[method_name] || 5.minutes
  end
end

# Policy audit trail mixin for compliance and debugging
module PolicyAudit
  private

  def build_audit_context
    {
      user_id: user&.id,
      user_role: user&.role,
      record_type: record&.class&.name,
      record_id: record&.id,
      action: caller_locations(2, 1).first.label,
      timestamp: Time.current,
      ip_address: context[:ip_address],
      user_agent: context[:user_agent]
    }
  end

  def log_policy_decision(decision, reason = nil)
    audit_log = build_audit_context.merge(
      decision: decision,
      reason: reason,
      cache_hit: context[:cache_hit]
    )

    Rails.logger.info("PolicyDecision: #{audit_log.to_json}")
  end
end

# Policy performance metrics mixin
module PolicyMetrics
  private

  def track_policy_performance
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    yield
  ensure
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    if duration > 0.1 # Log slow policy evaluations
      Rails.logger.warn("SlowPolicyEvaluation",
        policy: self.class.name,
        duration: duration,
        user_id: user&.id,
        record_type: record&.class&.name
      )
    end
  end
end

# Extensions for policy scopes
module PolicyScopeExtensions
  private

  def safe_resolve
    resolve
  rescue => e
    Rails.logger.error("PolicyScopeError: #{e.message}", policy_scope: self.class.name)
    scope.none # Return empty scope on error for security
  end
end
